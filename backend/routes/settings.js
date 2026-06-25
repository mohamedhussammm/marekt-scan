const express = require('express');
const router = express.Router();
const Settings = require('../models/Settings');
const { checkOwner } = require('../middleware/auth');

// Get Settings (returns settings scoped to the logged-in store)
router.get('/', async (req, res) => {
  try {
    let settings = await Settings.findOne({ storeName: req.storeName });
    if (!settings) {
      settings = new Settings({ storeName: req.storeName });
      await settings.save();
    }
    res.json({ success: true, settings });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

router.put('/', checkOwner, async (req, res) => {
  try {
    const { address, phone, email, taxRate, currency, notifications, darkMode } = req.body;
    
    // Construct safe update object
    const updatePayload = {};
    if (address !== undefined) updatePayload.address = address;
    if (phone !== undefined) updatePayload.phone = phone;
    if (email !== undefined) updatePayload.email = email;
    if (taxRate !== undefined) updatePayload.taxRate = Number(taxRate);
    if (currency !== undefined) updatePayload.currency = currency;
    if (notifications !== undefined) updatePayload.notifications = Boolean(notifications);
    if (darkMode !== undefined) updatePayload.darkMode = Boolean(darkMode);

    let settings = await Settings.findOne({ storeName: req.storeName });
    if (!settings) {
      settings = new Settings({ ...updatePayload, storeName: req.storeName });
    } else {
      Object.assign(settings, updatePayload);
      settings.storeName = req.storeName; // Enforce store context
    }
    await settings.save();
    res.json({ success: true, settings });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
