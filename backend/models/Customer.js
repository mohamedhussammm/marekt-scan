const mongoose = require('mongoose');

const customerSchema = new mongoose.Schema({
  storeName: { type: String, required: true, index: true },
  customerId: { type: String, required: true, unique: true, index: true },
  fullName: { type: String, required: true },
  phoneNumber: { type: String },
  address: { type: String }
}, { timestamps: true });

module.exports = mongoose.model('Customer', customerSchema);
