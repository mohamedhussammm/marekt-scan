const mongoose = require('mongoose');

const transactionSchema = new mongoose.Schema({
  receiptNumber: { type: String, required: true },
  storeName: { type: String, required: true, index: true },
  items: [{
    barcodeId: { type: String, required: true },
    name: { type: String, required: true },
    qty: { type: Number, required: true },
    unitPrice: { type: Number, required: true },
    lineTotal: { type: Number, required: true }
  }],
  totalAmount: { type: Number, required: true },
  paymentMethod: { type: String, required: true },
  shiftId: { type: mongoose.Schema.Types.ObjectId, ref: 'Shift' },
  cashierName: { type: String, default: 'المدير' }
}, { timestamps: true });

module.exports = mongoose.model('Transaction', transactionSchema);
