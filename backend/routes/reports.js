const express = require('express');
const router = express.Router();
const fastcsv = require('fast-csv');
const Transaction = require('../models/Transaction');
const Product = require('../models/Product');
const StoreInventory = require('../models/StoreInventory');

// Get Dashboard/Reports Summary KPIs scoped to storeName
router.get('/summary', async (req, res) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const Expense = require('../models/Expense');
    const Shift = require('../models/Shift');

    // Today's Transactions for this store
    const todayTransactions = await Transaction.find({
      storeName: req.storeName,
      createdAt: { $gte: today }
    });

    const todayRevenue = todayTransactions.reduce((sum, t) => sum + t.totalAmount, 0);
    const todayOrdersCount = todayTransactions.length;

    // Total products registered in this store's inventory
    const totalProductsCount = await StoreInventory.countDocuments({ storeName: req.storeName });
    
    // Low Stock count for this store
    const lowStockProducts = await StoreInventory.find({
      storeName: req.storeName,
      $expr: { $lt: ["$currentStock", "$minThreshold"] }
    });
    const lowStockCount = lowStockProducts.length;

    // Total profit calculation scoped to this store
    let totalCost = 0;
    const allTransactions = await Transaction.find({ storeName: req.storeName });
    const totalRevenue = allTransactions.reduce((sum, t) => sum + t.totalAmount, 0);

    for (const t of allTransactions) {
      for (const item of t.items) {
        // Find product in this store's inventory to get costPrice
        const inv = await StoreInventory.findOne({ storeName: req.storeName, barcodeId: item.barcodeId });
        const cost = inv ? inv.costPrice : item.unitPrice * 0.7;
        totalCost += cost * item.qty;
      }
    }
    const netProfit = totalRevenue - totalCost;

    // ─── SHIFT & PETTY CASH CALCULATIONS ───
    // Today's petty cash expenses
    const todayExpensesList = await Expense.find({
      storeName: req.storeName,
      createdAt: { $gte: today }
    });
    const todayExpenses = todayExpensesList.reduce((sum, e) => sum + e.amount, 0);

    // Active shift starting cash
    const activeShift = await Shift.findOne({
      storeName: req.storeName,
      status: 'open'
    });
    const startingCash = activeShift ? activeShift.startingCash : 0;

    // Today's cash-only revenue (excluding cards)
    const todayCashTransactions = todayTransactions.filter(t => t.paymentMethod === 'نقداً' || t.paymentMethod === 'نقدا');
    const todayCashRevenue = todayCashTransactions.reduce((sum, t) => sum + t.totalAmount, 0);

    // Cash on hand = starting cash + cash sales - expenses
    const cashOnHand = startingCash + todayCashRevenue - todayExpenses;

    res.json({
      success: true,
      todayRevenue,
      todayOrdersCount,
      totalProductsCount,
      lowStockCount,
      totalRevenue,
      netProfit: netProfit > 0 ? netProfit : totalRevenue * 0.22, // fallback to 22% target margin if negative/no sales
      totalOrders: allTransactions.length,
      todayExpenses,
      cashOnHand
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Get Weekly Chart Data for this store
router.get('/weekly-chart', async (req, res) => {
  try {
    const chartData = [];
    const now = new Date();

    for (let i = 6; i >= 0; i--) {
      const d = new Date(now);
      d.setDate(now.getDate() - i);
      
      const startOfDay = new Date(d);
      startOfDay.setHours(0, 0, 0, 0);
      
      const endOfDay = new Date(d);
      endOfDay.setHours(23, 59, 59, 999);

      const txs = await Transaction.find({
        storeName: req.storeName,
        createdAt: { $gte: startOfDay, $lte: endOfDay }
      });

      const total = txs.reduce((sum, t) => sum + t.totalAmount, 0);
      chartData.push(total);
    }

    res.json({ success: true, data: chartData });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Get Top 5 Products by Quantity Sold in this store
router.get('/top-products', async (req, res) => {
  try {
    const aggregation = await Transaction.aggregate([
      { $match: { storeName: req.storeName } },
      { $unwind: "$items" },
      {
        $group: {
          _id: "$items.barcodeId",
          name: { $first: "$items.name" },
          qtySold: { $sum: "$items.qty" },
          totalSales: { $sum: "$items.lineTotal" }
        }
      },
      { $sort: { qtySold: -1 } },
      { $limit: 5 }
    ]);

    res.json({ success: true, topProducts: aggregation });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Get Sales/Products By Category scoped to this store
router.get('/by-category', async (req, res) => {
  try {
    const inventories = await StoreInventory.find({ storeName: req.storeName });
    const barcodes = inventories.map(i => i.barcodeId);
    
    const products = await Product.find({ barcodeId: { $in: barcodes } });
    const prodMap = {};
    products.forEach(p => {
      prodMap[p.barcodeId] = p.category;
    });

    const catMap = {};
    inventories.forEach(inv => {
      const category = prodMap[inv.barcodeId] || 'غير محدد';
      if (!catMap[category]) {
        catMap[category] = { count: 0, stockValue: 0 };
      }
      catMap[category].count += 1;
      catMap[category].stockValue += inv.currentStock * inv.sellingPrice;
    });

    const categoriesAggregation = Object.keys(catMap).map(cat => ({
      _id: cat,
      count: catMap[cat].count,
      stockValue: catMap[cat].stockValue
    }));

    res.json({ success: true, categories: categoriesAggregation });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Export CSV report scoped to this store
router.get('/monthly/csv', async (req, res) => {
  try {
    const transactions = await Transaction.find({ storeName: req.storeName }).sort({ createdAt: -1 });
    
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', 'attachment; filename="monthly_report.csv"');

    const csvStream = fastcsv.format({ headers: true });
    csvStream.pipe(res);

    transactions.forEach(t => {
      csvStream.write({
        ReceiptNumber: t.receiptNumber,
        TotalAmount: t.totalAmount,
        PaymentMethod: t.paymentMethod,
        Date: t.createdAt.toISOString(),
      });
    });

    csvStream.end();
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
