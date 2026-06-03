const mongoose = require('mongoose');

const shiftSchema = new mongoose.Schema({
  storeName: { type: String, required: true },
  cashierUsername: { type: String, required: true },
  startTime: { type: Date, required: true, default: Date.now },
  endTime: { type: Date },
  status: { type: String, enum: ['open', 'closed'], default: 'open' },
  startingCash: { type: Number, required: true, default: 0 },
  endingCash: { type: Number },
  totalSales: { type: Number, default: 0 },
  paymentMethodsBreakdown: {
    cash: { type: Number, default: 0 },
    card: { type: Number, default: 0 }
  }
}, { timestamps: true });

module.exports = mongoose.model('Shift', shiftSchema);
