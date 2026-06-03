const mongoose = require('mongoose');
const Product = require('../models/Product');
const StoreInventory = require('../models/StoreInventory');
const Transaction = require('../models/Transaction');
const Shift = require('../models/Shift');

exports.createTransaction = async (req, res) => {
  try {
    const { items, totalAmount, paymentMethod } = req.body;
    
    // 0. Verify if there is an active open shift (for cashiers)
    const activeShift = await Shift.findOne({ storeName: req.storeName, status: 'open' });
    if (req.userRole === 'cashier' && !activeShift) {
      return res.status(400).json({ success: false, error: 'الرجاء فتح الوردية أولاً قبل إتمام عملية البيع' });
    }

    // 1. Verify all products exist and have sufficient stock in this store's inventory
    for (const item of items) {
      const product = await Product.findOne({ barcodeId: item.barcodeId });
      if (!product) {
        return res.status(404).json({ success: false, error: `المنتج غير موجود: ${item.barcodeId}` });
      }
      
      const inventory = await StoreInventory.findOne({ storeName: req.storeName, barcodeId: item.barcodeId });
      if (!inventory) {
        return res.status(400).json({ success: false, error: `المنتج غير مسجل في مخزون هذا المتجر: ${product.name}` });
      }
      
      if (inventory.currentStock < item.qty) {
        return res.status(400).json({ success: false, error: `الكمية غير كافية في مخزون هذا المتجر للمنتج: ${product.name}` });
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
      receiptNumber,
      storeName: req.storeName,
      items,
      totalAmount,
      paymentMethod,
      shiftId: activeShift ? activeShift._id : undefined,
      cashierName: req.userRole === 'admin' ? 'المدير' : (req.username || 'المدير')
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
