const mongoose = require('mongoose');

const securityLogSchema = new mongoose.Schema({
  username: { type: String, required: true },
  storeName: { type: String, required: true },
  action: { type: String, required: true },
  details: { type: String, default: '' },
  timestamp: { type: Date, default: Date.now }
});

module.exports = mongoose.model('SecurityLog', securityLogSchema);
