const express = require('express');
const router = express.Router();
const Supplier = require('../models/Supplier');
const { checkOwner } = require('../middleware/auth');

// Get all suppliers for this store
router.get('/', async (req, res) => {
  try {
    const suppliers = await Supplier.find({ storeName: req.storeName });
    res.json({ success: true, suppliers });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Add new supplier (Owner only)
router.post('/', checkOwner, async (req, res) => {
  try {
    const { name, phone, categories, whatsappEnabled } = req.body;
    if (!name || !phone) {
      return res.status(400).json({ success: false, error: 'اسم المورد ورقم الهاتف مطلوبان' });
    }

    const supplier = new Supplier({
      storeName: req.storeName,
      name: name.trim(),
      phone: phone.trim(),
      categories: Array.isArray(categories) ? categories : [],
      whatsappEnabled: whatsappEnabled !== undefined ? Boolean(whatsappEnabled) : true
    });
    
    await supplier.save();
    res.status(201).json({ success: true, supplier });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
});

module.exports = router;
