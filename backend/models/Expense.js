const mongoose = require('mongoose');

const expenseSchema = new mongoose.Schema({
  storeName: { type: String, required: true },
  cashierUsername: { type: String, required: true },
  shiftId: { type: mongoose.Schema.Types.ObjectId, ref: 'Shift' },
  amount: { type: Number, required: true },
  description: { type: String, required: true },
  timestamp: { type: Date, default: Date.now }
}, { timestamps: true });

module.exports = mongoose.model('Expense', expenseSchema);
