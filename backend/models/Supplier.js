const mongoose = require('mongoose');

const supplierSchema = new mongoose.Schema({
  storeName: { type: String, required: true, index: true },
  name: { type: String, required: true },
  phone: { type: String, required: true },
  categories: [{ type: String }],
  whatsappEnabled: { type: Boolean, default: true }
}, { timestamps: true });

module.exports = mongoose.model('Supplier', supplierSchema);
