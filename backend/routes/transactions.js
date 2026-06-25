const express = require('express');
const router = express.Router();
const salesController = require('../controllers/salesController');
const Transaction = require('../models/Transaction');
const Expense = require('../models/Expense');

router.post('/', salesController.createTransaction);

// Get transactions and expenses merged with optimized database-level pagination
router.get('/', async (req, res) => {
  try {
    const limit = Math.max(1, parseInt(req.query.limit) || 50);
    const skip = Math.max(0, parseInt(req.query.skip) || 0);

    const merged = await Transaction.aggregate([
      { $match: { storeName: req.storeName } },
      {
        $project: {
          _id: 1,
          offline_id: 1,
          receiptNumber: 1,
          totalAmount: 1,
          paymentMethod: 1,
          items: 1,
          createdAt: 1,
          cashierName: 1,
          type: { $literal: 'sale' }
        }
      },
      {
        $unionWith: {
          coll: 'expenses',
          pipeline: [
            { $match: { storeName: req.storeName } },
            {
              $project: {
                _id: 1,
                offline_id: 1,
                receiptNumber: { $concat: ["EXP-", { $substrCP: [{ $toString: "$_id" }, 18, 6] }] },
                totalAmount: "$amount",
                paymentMethod: { $literal: 'نقداً' },
                items: [
                  {
                    barcodeId: "EXPENSE",
                    name: "$description",
                    qty: 1,
                    unitPrice: "$amount",
                    lineTotal: "$amount"
                  }
                ],
                createdAt: 1,
                cashierName: "$cashierUsername",
                type: { $literal: 'expense' }
              }
            }
          ]
        }
      },
      { $sort: { createdAt: -1 } },
      { $skip: skip },
      { $limit: limit }
    ]);

    res.json({ success: true, transactions: merged });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
