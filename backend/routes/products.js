const express = require('express');
const router = express.Router();
const Product = require('../models/Product');
const StoreInventory = require('../models/StoreInventory');
const { checkOwner } = require('../middleware/auth');

// ─── GET /api/products/low-stock ─────────────────────────────────────────────
// Returns only low-stock items for a store, paginated.
// MongoDB does the filtering — no need to send 3200 products to the client.
// Query params: page (default 1), limit (default 30)
router.get('/low-stock', async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(100, parseInt(req.query.limit) || 30);
    const skip = (page - 1) * limit;
    const storeName = req.storeName;

    // Aggregate: join StoreInventory with Product where currentStock <= minThreshold
    const pipeline = [
      {
        $match: {
          storeName: storeName,
          $expr: { $lte: ['$currentStock', '$minThreshold'] }
        }
      },
      {
        $lookup: {
          from: 'products',
          localField: 'barcodeId',
          foreignField: 'barcodeId',
          as: 'productInfo'
        }
      },
      { $unwind: { path: '$productInfo', preserveNullAndEmptyArrays: false } },
      {
        $project: {
          _id: '$productInfo._id',
          barcodeId: '$barcodeId',
          name: '$productInfo.name',
          category: '$productInfo.category',
          sellingPrice: '$sellingPrice',
          costPrice: '$costPrice',
          currentStock: '$currentStock',
          minThreshold: '$minThreshold',
          isRegistered: { $literal: true }
        }
      },
      { $sort: { currentStock: 1 } } // Most critical first
    ];

    const countPipeline = [
      {
        $match: {
          storeName: storeName,
          $expr: { $lte: ['$currentStock', '$minThreshold'] }
        }
      },
      { $count: 'total' }
    ];

    const [items, countResult] = await Promise.all([
      StoreInventory.aggregate([...pipeline, { $skip: skip }, { $limit: limit }]),
      StoreInventory.aggregate(countPipeline)
    ]);

    const total = countResult[0]?.total ?? 0;

    res.json({
      success: true,
      products: items,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasMore: skip + items.length < total
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

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

// Get products — paginated, searchable, filterable
// Query params:
//   page     (default 1)
//   limit    (default 40, max 100)
//   search   (partial name or barcode match, case-insensitive)
//   category (exact match, empty = all)
router.get('/', async (req, res) => {
  try {
    const page     = Math.max(1, parseInt(req.query.page)  || 1);
    const limit    = Math.min(100, parseInt(req.query.limit) || 40);
    const skip     = (page - 1) * limit;
    const search   = req.query.search   ? req.query.search.trim()   : '';
    const category = req.query.category ? req.query.category.trim() : '';

    const escapeRegex = (string) => string.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');

    // Build MongoDB filter on the Product catalog
    const productFilter = {};
    if (search) {
      const escapedSearch = escapeRegex(search);
      productFilter.$or = [
        { name:      { $regex: escapedSearch, $options: 'i' } },
        { barcodeId: { $regex: escapedSearch, $options: 'i' } },
      ];
    }
    if (category) {
      productFilter.category = category;
    }

    const [products, total] = await Promise.all([
      Product.find(productFilter).skip(skip).limit(limit).lean(),
      Product.countDocuments(productFilter),
    ]);

    // Fetch only the inventory rows we actually need (by the page of barcodes)
    const barcodeIds = products.map(p => p.barcodeId);
    const inventories = await StoreInventory.find({
      storeName: req.storeName,
      barcodeId: { $in: barcodeIds },
    }).lean();

    const invMap = {};
    inventories.forEach(inv => { invMap[inv.barcodeId] = inv; });

    const mergedProducts = products.map(p => {
      const inv = invMap[p.barcodeId];
      return {
        _id:          p._id,
        barcodeId:    p.barcodeId,
        name:         p.name,
        category:     p.category,
        sellingPrice: inv ? inv.sellingPrice : 0,
        costPrice:    inv ? inv.costPrice    : 0,
        currentStock: inv ? inv.currentStock : 0,
        minThreshold: inv ? inv.minThreshold : 10,
        isRegistered: !!inv,
      };
    });

    res.json({
      success: true,
      products: mergedProducts,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasMore: skip + mergedProducts.length < total,
      },
    });
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
