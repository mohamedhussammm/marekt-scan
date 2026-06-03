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

// Update Settings (updates settings scoped to the logged-in store)
router.put('/', checkOwner, async (req, res) => {
  try {
    let settings = await Settings.findOne({ storeName: req.storeName });
    if (!settings) {
      // Merge req.body and force storeName
      settings = new Settings({ ...req.body, storeName: req.storeName });
    } else {
      Object.assign(settings, req.body);
      settings.storeName = req.storeName; // Enforce store context
    }
    await settings.save();
    res.json({ success: true, settings });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
