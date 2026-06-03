const express = require('express');
const router = express.Router();
const salesController = require('../controllers/salesController');
const Transaction = require('../models/Transaction');
const Expense = require('../models/Expense');

router.post('/', salesController.createTransaction);

// Get transactions and expenses merged with optional pagination
router.get('/', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const skip = parseInt(req.query.skip) || 0;

    // Fetch transactions
    const transactions = await Transaction.find({ storeName: req.storeName })
      .sort({ createdAt: -1 })
      .limit(limit + skip);

    // Fetch expenses
    const expenses = await Expense.find({ storeName: req.storeName })
      .sort({ createdAt: -1 })
      .limit(limit + skip);

    // Map and tag them
    const mappedTransactions = transactions.map(t => ({
      ...t.toObject(),
      type: 'sale'
    }));

    const mappedExpenses = expenses.map(e => ({
      _id: e._id,
      receiptNumber: `EXP-${e._id.toString().substring(18)}`,
      totalAmount: e.amount,
      paymentMethod: 'نقداً',
      items: [{
        barcodeId: 'EXPENSE',
        name: e.description,
        qty: 1,
        unitPrice: e.amount,
        lineTotal: e.amount
      }],
      type: 'expense',
      createdAt: e.createdAt
    }));

    // Merge and sort
    let merged = [...mappedTransactions, ...mappedExpenses]
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    // Apply skip and limit
    if (skip > 0) {
      merged = merged.slice(skip);
    }
    if (limit > 0) {
      merged = merged.slice(0, limit);
    }

    res.json({ success: true, transactions: merged });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
