const express = require('express');
const router = express.Router();
const Product = require('../models/Product');
const StoreInventory = require('../models/StoreInventory');
const { checkOwner } = require('../middleware/auth');

// Get product by barcode
router.get('/:barcode', async (req, res) => {
  try {
    const product = await Product.findOne({ barcodeId: req.params.barcode });
    if (!product) return res.status(404).json({ success: false, message: 'Product not found' });
    
    // Find store inventory override
    const inventory = await StoreInventory.findOne({ storeName: req.storeName, barcodeId: req.params.barcode });
    
    res.json({
      success: true,
      product: {
        _id: product._id,
        barcodeId: product.barcodeId,
        name: product.name,
        category: product.category,
        sellingPrice: inventory ? inventory.sellingPrice : 0,
        costPrice: inventory ? inventory.costPrice : 0,
        currentStock: inventory ? inventory.currentStock : 0,
        minThreshold: inventory ? inventory.minThreshold : 10,
        isRegistered: !!inventory
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Add new product
router.post('/', checkOwner, async (req, res) => {
  try {
    const { barcodeId, name, category, sellingPrice, costPrice, currentStock, minThreshold } = req.body;
    
    // Create or find product in global catalog
    let product = await Product.findOne({ barcodeId });
    if (!product) {
      product = new Product({ barcodeId, name, category });
      await product.save();
    }
    
    // Create or update store inventory override
    const inventory = await StoreInventory.findOneAndUpdate(
      { storeName: req.storeName, barcodeId },
      {
        $set: {
          sellingPrice: sellingPrice || 0,
          costPrice: costPrice || 0,
          currentStock: currentStock || 0,
          minThreshold: minThreshold || 10
        }
      },
      { upsert: true, new: true }
    );
    
    res.status(201).json({
      success: true,
      product: {
        _id: product._id,
        barcodeId: product.barcodeId,
        name: product.name,
        category: product.category,
        sellingPrice: inventory.sellingPrice,
        costPrice: inventory.costPrice,
        currentStock: inventory.currentStock,
        minThreshold: inventory.minThreshold,
        isRegistered: true
      }
    });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
});

// Update stock
router.put('/:barcode/stock', checkOwner, async (req, res) => {
  try {
    const { quantity } = req.body;
    const inventory = await StoreInventory.findOneAndUpdate(
      { storeName: req.storeName, barcodeId: req.params.barcode },
      { $inc: { currentStock: quantity } },
      { new: true, upsert: true }
    );
    
    const product = await Product.findOne({ barcodeId: req.params.barcode });
    
    res.json({
      success: true,
      product: {
        _id: product ? product._id : null,
        barcodeId: req.params.barcode,
        name: product ? product.name : '',
        category: product ? product.category : '',
        sellingPrice: inventory.sellingPrice,
        costPrice: inventory.costPrice,
        currentStock: inventory.currentStock,
        minThreshold: inventory.minThreshold,
        isRegistered: true
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Get all products
router.get('/', async (req, res) => {
  try {
    const products = await Product.find();
    const inventories = await StoreInventory.find({ storeName: req.storeName });
    
    // Map inventories by barcodeId for O(1) lookups
    const invMap = {};
    inventories.forEach(inv => {
      invMap[inv.barcodeId] = inv;
    });
    
    const mergedProducts = products.map(p => {
      const inv = invMap[p.barcodeId];
      return {
        _id: p._id,
        barcodeId: p.barcodeId,
        name: p.name,
        category: p.category,
        sellingPrice: inv ? inv.sellingPrice : 0,
        costPrice: inv ? inv.costPrice : 0,
        currentStock: inv ? inv.currentStock : 0,
        minThreshold: inv ? inv.minThreshold : 10,
        isRegistered: !!inv
      };
    });
    
    res.json({ success: true, products: mergedProducts });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Update product
router.put('/:barcode', checkOwner, async (req, res) => {
  try {
    const { name, category, sellingPrice, costPrice, currentStock, minThreshold } = req.body;
    
    // 1. Update global product catalog
    const product = await Product.findOneAndUpdate(
      { barcodeId: req.params.barcode },
      { $set: { name, category } },
      { new: true, upsert: true }
    );
    
    // 2. Update/upsert store inventory override
    const inventory = await StoreInventory.findOneAndUpdate(
      { storeName: req.storeName, barcodeId: req.params.barcode },
      {
        $set: {
          sellingPrice: sellingPrice !== undefined ? sellingPrice : 0,
          costPrice: costPrice !== undefined ? costPrice : 0,
          currentStock: currentStock !== undefined ? currentStock : 0,
          minThreshold: minThreshold !== undefined ? minThreshold : 10
        }
      },
      { new: true, upsert: true }
    );
    
    res.json({
      success: true,
      product: {
        _id: product._id,
        barcodeId: product.barcodeId,
        name: product.name,
        category: product.category,
        sellingPrice: inventory.sellingPrice,
        costPrice: inventory.costPrice,
        currentStock: inventory.currentStock,
        minThreshold: inventory.minThreshold,
        isRegistered: true
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Delete product
router.delete('/:barcode', checkOwner, async (req, res) => {
  try {
    // Delete this store's override entry
    await StoreInventory.findOneAndDelete({ storeName: req.storeName, barcodeId: req.params.barcode });
    res.json({ success: true, message: 'Product deleted from store successfully' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
