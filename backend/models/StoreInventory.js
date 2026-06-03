const mongoose = require('mongoose');

const storeInventorySchema = new mongoose.Schema({
  storeName: { type: String, required: true, index: true },
  barcodeId: { type: String, required: true, index: true },
  sellingPrice: { type: Number, required: true },
  costPrice: { type: Number, required: true },
  currentStock: { type: Number, required: true },
  minThreshold: { type: Number, default: 10 }
}, { timestamps: true });

// Enforce multi-tenant data isolation and prevent duplicates
storeInventorySchema.index({ storeName: 1, barcodeId: 1 }, { unique: true });

module.exports = mongoose.model('StoreInventory', storeInventorySchema);
