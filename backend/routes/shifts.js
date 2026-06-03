const express = require('express');
const router = express.Router();
const Shift = require('../models/Shift');
const Expense = require('../models/Expense');
const Transaction = require('../models/Transaction');

// Get active shift for store
router.get('/active', async (req, res) => {
  try {
    const shift = await Shift.findOne({
      storeName: req.storeName,
      status: 'open'
    });
    res.json({ success: true, shift });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Open new shift
router.post('/open', async (req, res) => {
  try {
    const { startingCash } = req.body;
    // Check if there's already an active shift for this store
    const existing = await Shift.findOne({
      storeName: req.storeName,
      status: 'open'
    });
    if (existing) {
      return res.status(400).json({ success: false, error: 'توجد وردية مفتوحة بالفعل لهذا المتجر' });
    }

    const shift = new Shift({
      storeName: req.storeName,
      cashierUsername: req.username || 'unknown',
      startingCash: startingCash || 0,
      status: 'open'
    });
    await shift.save();
    res.status(201).json({ success: true, shift });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Close shift
router.post('/close', async (req, res) => {
  try {
    const { endingCash } = req.body;
    const shift = await Shift.findOne({
      storeName: req.storeName,
      status: 'open'
    });
    if (!shift) {
      return res.status(404).json({ success: false, error: 'لا توجد وردية مفتوحة لإغلاقها' });
    }

    // Recalculate metrics based on transactions and expenses during this shift
    const expenses = await Expense.find({ shiftId: shift._id });
    const totalExpenses = expenses.reduce((sum, e) => sum + e.amount, 0);

    const transactions = await Transaction.find({
      storeName: req.storeName,
      createdAt: { $gte: shift.startTime }
    });
    
    let totalSales = 0;
    let cashSales = 0;
    let cardSales = 0;
    for (const t of transactions) {
      totalSales += t.totalAmount;
      if (t.paymentMethod === 'نقداً') {
        cashSales += t.totalAmount;
      } else {
        cardSales += t.totalAmount;
      }
    }

    shift.endTime = new Date();
    shift.status = 'closed';
    shift.endingCash = endingCash;
    shift.totalSales = totalSales;
    shift.paymentMethodsBreakdown = {
      cash: cashSales,
      card: cardSales
    };

    await shift.save();
    res.json({ success: true, shift, totalExpenses });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Get shift history (limited to 50 for performance)
router.get('/history', async (req, res) => {
  try {
    const shifts = await Shift.find({ storeName: req.storeName })
      .sort({ createdAt: -1 })
      .limit(50);
    res.json({ success: true, shifts });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
