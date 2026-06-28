const mongoose = require('mongoose');
const Product = require('../models/Product');
const StoreInventory = require('../models/StoreInventory');
const Transaction = require('../models/Transaction');
const Shift = require('../models/Shift');
const Settings = require('../models/Settings');

exports.createTransaction = async (req, res) => {
  try {
    const { items, totalAmount, amountPaid, paymentMethod, offline_id, customerId, changeReturned } = req.body;

    // ── INPUT VALIDATION ──────────────────────────────────────────────────
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ success: false, error: 'يجب أن تحتوي المعاملة على منتج واحد على الأقل' });
    }

    if (typeof totalAmount !== 'number' || totalAmount <= 0) {
      return res.status(400).json({ success: false, error: 'إجمالي مبلغ البيع غير صالح' });
    }

    const allowedPaymentMethods = ['نقداً', 'نقدا', 'بطاقة', 'تحويل', 'Visa', 'Mastercard', 'Cash', 'كاش', 'فيزا'];
    if (!paymentMethod || !allowedPaymentMethods.includes(paymentMethod)) {
      return res.status(400).json({ success: false, error: 'طريقة الدفع غير صالحة' });
    }

    let calculatedTotal = 0;
    for (const item of items) {
      if (!item || !item.barcodeId || !item.name) {
        return res.status(400).json({ success: false, error: 'بيانات المنتج غير مكتملة في بنود الفاتورة' });
      }
      
      const qty = Number(item.qty);
      const unitPrice = Number(item.unitPrice);
      const lineTotal = Number(item.lineTotal);

      if (isNaN(qty) || qty <= 0) {
        return res.status(400).json({ success: false, error: `الكمية غير صالحة للمنتج: ${item.name}` });
      }
      if (isNaN(unitPrice) || unitPrice < 0) {
        return res.status(400).json({ success: false, error: `سعر المنتج غير صالح: ${item.name}` });
      }
      if (isNaN(lineTotal) || lineTotal < 0) {
        return res.status(400).json({ success: false, error: `إجمالي السطر غير صالح للمنتج: ${item.name}` });
      }

      // Check line total integrity (allow small rounding difference for floating point math)
      const expectedLineTotal = qty * unitPrice;
      if (Math.abs(lineTotal - expectedLineTotal) > 0.05) {
        return res.status(400).json({ success: false, error: `حساب إجمالي السطر خاطئ للمنتج: ${item.name}` });
      }

      calculatedTotal += lineTotal;
    }

    // Check overall total amount integrity (allow both tax-inclusive and tax-exclusive totals)
    const settings = await Settings.findOne({ storeName: req.storeName });
    const taxRate = settings ? (settings.taxRate ?? 14) : 14;
    const expectedTaxInclusive = calculatedTotal * (1 + taxRate / 100);

    const diffExclusive = Math.abs(totalAmount - calculatedTotal);
    const diffInclusive = Math.abs(totalAmount - expectedTaxInclusive);

    if (diffExclusive > 0.5 && diffInclusive > 0.5) {
      return res.status(400).json({ success: false, error: 'المبلغ الإجمالي للمعاملة لا يطابق مجموع بنود البيع' });
    }
    // ── END INPUT VALIDATION ──────────────────────────────────────────────

    // ── IDEMPOTENCY GUARD ────────────────────────────────────────────────
    if (offline_id) {
      const existing = await Transaction.findOne({ storeName: req.storeName, offline_id: offline_id });
      if (existing) {
        return res.status(200).json({
          success: true,
          transactionId: existing._id,
          receiptNumber: existing.receiptNumber,
          totalAmount: existing.totalAmount,
          idempotent: true
        });
      }
    }
    // ── END IDEMPOTENCY GUARD ────────────────────────────────────────────
    
    // 0. Verify if there is an active open shift (for cashiers)
    const activeShift = await Shift.findOne({ storeName: req.storeName, status: 'open' });
    if (req.userRole === 'cashier' && !activeShift) {
      return res.status(400).json({ success: false, error: 'الرجاء فتح الوردية أولاً قبل إتمام عملية البيع' });
    }

    // 1. Verify all products exist and ensure they have StoreInventory records
    for (const item of items) {
      const product = await Product.findOne({ barcodeId: item.barcodeId });
      if (!product) {
        return res.status(404).json({ success: false, error: `المنتج غير موجود: ${item.barcodeId}` });
      }
      
      const inventory = await StoreInventory.findOne({ storeName: req.storeName, barcodeId: item.barcodeId });
      if (!inventory) {
        // Dynamically create StoreInventory record using global product details
        await StoreInventory.create({
          storeName: req.storeName,
          barcodeId: item.barcodeId,
          sellingPrice: product.sellingPrice || 0,
          costPrice: product.costPrice || 0,
          currentStock: 0,
          minThreshold: 10
        });
      }
    }
    
    // 2. Decrement stock levels in this store's inventory
    for (const item of items) {
      await StoreInventory.updateOne(
        { storeName: req.storeName, barcodeId: item.barcodeId },
        { $inc: { currentStock: -item.qty } }
      );
    }
    
    // 3. Create the transaction record scoped to this store and link shiftId
    const receiptNumber = "RCP-" + Date.now();
    const transaction = await Transaction.create({
      offline_id: offline_id || undefined,
      receiptNumber,
      storeName: req.storeName,
      items,
      totalAmount,
      amountPaid: amountPaid !== undefined ? amountPaid : totalAmount,
      paymentMethod,
      shiftId: activeShift ? activeShift._id : undefined,
      cashierName: req.userRole === 'admin' ? 'المدير' : (req.username || 'المدير'),
      customerId: customerId || undefined,
      changeReturned: changeReturned || 0
    });

    // 4. Increment active shift metrics
    if (activeShift) {
      activeShift.totalSales += totalAmount;
      if (paymentMethod === 'نقداً' || paymentMethod === 'نقدا') {
        activeShift.paymentMethodsBreakdown.cash += totalAmount;
      } else {
        activeShift.paymentMethodsBreakdown.card += totalAmount;
      }
      await activeShift.save();
    }
    
    res.status(201).json({
      success: true,
      transactionId: transaction._id,
      receiptNumber,
      totalAmount
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};
