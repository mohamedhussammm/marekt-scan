const mongoose = require('mongoose');

const productSchema = new mongoose.Schema({
  barcodeId: { type: String, required: true, unique: true },
  name: { type: String, required: true },
  category: { type: String, required: true }
}, { timestamps: true });

module.exports = mongoose.model('Product', productSchema);
