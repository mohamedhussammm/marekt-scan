const express = require('express');
const router = express.Router();
const Customer = require('../models/Customer');
const Transaction = require('../models/Transaction');

// Create a new customer
router.post('/', async (req, res) => {
  try {
    const { customerId, fullName, phoneNumber, address } = req.body;

    if (!fullName || fullName.trim().length === 0) {
      return res.status(400).json({ success: false, error: 'الاسم الكامل مطلوب' });
    }

    const existing = await Customer.findOne({ customerId });
    if (existing) {
      return res.status(400).json({ success: false, error: 'معرف العميل موجود بالفعل' });
    }

    const customer = new Customer({
      storeName: req.storeName,
      customerId: customerId || 'CUST-' + Date.now(),
      fullName: fullName.trim(),
      phoneNumber: phoneNumber ? phoneNumber.trim() : '',
      address: address ? address.trim() : ''
    });

    await customer.save();
    res.status(201).json({ success: true, customer });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// List all customers
router.get('/', async (req, res) => {
  try {
    const customers = await Customer.find({ storeName: req.storeName }).sort({ createdAt: -1 });
    res.json({ success: true, customers });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Edit customer details
router.put('/:customerId', async (req, res) => {
  try {
    const { customerId } = req.params;
    const { fullName, phoneNumber, address } = req.body;

    if (!fullName || fullName.trim().length === 0) {
      return res.status(400).json({ success: false, error: 'الاسم الكامل مطلوب' });
    }

    const customer = await Customer.findOne({ storeName: req.storeName, customerId });
    if (!customer) {
      return res.status(404).json({ success: false, error: 'العميل غير موجود' });
    }

    customer.fullName = fullName.trim();
    customer.phoneNumber = phoneNumber ? phoneNumber.trim() : '';
    customer.address = address ? address.trim() : '';

    await customer.save();
    res.json({ success: true, customer });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Get customer purchase history
router.get('/:customerId/history', async (req, res) => {
  try {
    const { customerId } = req.params;
    const transactions = await Transaction.find({
      storeName: req.storeName,
      customerId: customerId
    }).sort({ createdAt: -1 });

    res.json({ success: true, transactions });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
