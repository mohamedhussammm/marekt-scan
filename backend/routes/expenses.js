const express = require('express');
const router = express.Router();
const Expense = require('../models/Expense');
const Shift = require('../models/Shift');

// Create petty cash expense
router.post('/', async (req, res) => {
  try {
    const { amount, description, category } = req.body;
    
    const parsedAmount = parseFloat(amount);
    if (isNaN(parsedAmount) || parsedAmount <= 0) {
      return res.status(400).json({ success: false, error: 'يجب أن يكون مبلغ المصروفات أكبر من صفر' });
    }

    if (!description || description.trim().length === 0) {
      return res.status(400).json({ success: false, error: 'الوصف مطلوب' });
    }

    if (description.length > 200) {
      return res.status(400).json({ success: false, error: 'الوصف طويل جداً (الحد الأقصى 200 حرف)' });
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
      amount: parsedAmount,
      category: (category || 'أخرى').substring(0, 50),
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
    const { shiftId, all, category } = req.query;
    let query = { storeName: req.storeName };
    
    if (category) {
      query.category = category;
    }

    if (shiftId) {
      query.shiftId = shiftId;
    } else if (all !== 'true') {
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

// Get expenses aggregated by category
router.get('/category-summary', async (req, res) => {
  try {
    const summary = await Expense.aggregate([
      { $match: { storeName: req.storeName } },
      { $group: { _id: '$category', total: { $sum: '$amount' } } }
    ]);
    res.json({ success: true, summary });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Edit petty cash expense
router.put('/:id', async (req, res) => {
  try {
    const { amount, description, category } = req.body;
    const parsedAmount = parseFloat(amount);
    if (isNaN(parsedAmount) || parsedAmount <= 0) {
      return res.status(400).json({ success: false, error: 'يجب أن يكون مبلغ المصروفات أكبر من صفر' });
    }

    if (!description || description.trim().length === 0) {
      return res.status(400).json({ success: false, error: 'الوصف مطلوب' });
    }

    const expense = await Expense.findOneAndUpdate(
      { _id: req.params.id, storeName: req.storeName },
      { 
        $set: { 
          amount: parsedAmount,
          description: description.trim(),
          category: (category || 'أخرى').substring(0, 50)
        } 
      },
      { new: true }
    );

    if (!expense) {
      return res.status(404).json({ success: false, error: 'المصروف غير موجود' });
    }

    res.json({ success: true, expense });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Delete petty cash expense
router.delete('/:id', async (req, res) => {
  try {
    const expense = await Expense.findOneAndDelete({ _id: req.params.id, storeName: req.storeName });
    if (!expense) {
      return res.status(404).json({ success: false, error: 'المصروف غير موجود' });
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
