const express = require('express');
const router = express.Router();
const SecurityLog = require('../models/SecurityLog');

// Log security/restricted access attempt
router.post('/restricted', async (req, res) => {
  try {
    const { action, details } = req.body;
    const log = new SecurityLog({
      username: req.username || 'unknown',
      storeName: req.storeName || 'unknown',
      action: action || 'UNAUTHORIZED_ACTION',
      details: details || ''
    });
    await log.save();
    console.warn(`[SECURITY WARN] Store: ${req.storeName}, User: ${req.username} attempted restricted action: ${action}`);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
