const express = require('express');
const router = express.Router();
const Expense = require('../models/Expense');
const Shift = require('../models/Shift');

// Create petty cash expense
router.post('/', async (req, res) => {
  try {
    const { amount, description } = req.body;
    if (!amount || !description) {
      return res.status(400).json({ success: false, error: 'المبلغ والوصف مطلوبان' });
    }

    // Find active shift to link
    const activeShift = await Shift.findOne({
      storeName: req.storeName,
      status: 'open'
    });

    const expense = new Expense({
      storeName: req.storeName,
      cashierUsername: req.username || 'unknown',
      shiftId: activeShift ? activeShift._id : null,
      amount: parseFloat(amount),
      description: description.trim()
    });

    await expense.save();
    
    res.status(201).json({ success: true, expense });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Get current expenses
router.get('/', async (req, res) => {
  try {
    const { shiftId } = req.query;
    let query = { storeName: req.storeName };
    if (shiftId) {
      query.shiftId = shiftId;
    } else {
      // Default to today's expenses
      const startOfDay = new Date();
      startOfDay.setHours(0, 0, 0, 0);
      query.createdAt = { $gte: startOfDay };
    }

    const expenses = await Expense.find(query).sort({ createdAt: -1 });
    res.json({ success: true, expenses });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
