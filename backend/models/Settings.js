const mongoose = require('mongoose');

const settingsSchema = new mongoose.Schema({
  storeName: { type: String, required: true, unique: true, index: true },
  address: { type: String, default: 'القاهرة، مصر' },
  phone: { type: String, default: '+20 10 0000 0000' },
  email: { type: String, default: 'admin@marketscan.com' },
  taxRate: { type: Number, default: 14 },
  currency: { type: String, default: 'EGP' },
  notifications: { type: Boolean, default: true },
  darkMode: { type: Boolean, default: false }
}, { timestamps: true });

module.exports = mongoose.model('Settings', settingsSchema);
