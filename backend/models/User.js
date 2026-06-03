const mongoose = require('mongoose');
const crypto = require('crypto');

const userSchema = new mongoose.Schema({
  username: { type: String, required: true, unique: true },
  email: { type: String, default: '' },
  passwordHash: { type: String, required: true },
  salt: { type: String, required: true },
  storeName: { type: String, default: 'سوبر ماركت النيل' },
  role: { type: String, default: 'cashier' }
}, { timestamps: true });

// Helper to hash password using Node.js crypto (scrypt/pbkdf2)
userSchema.methods.setPassword = function(password) {
  this.salt = crypto.randomBytes(16).toString('hex');
  this.passwordHash = crypto.pbkdf2Sync(password, this.salt, 1000, 64, 'sha512').toString('hex');
};

userSchema.methods.validPassword = function(password) {
  const hash = crypto.pbkdf2Sync(password, this.salt, 1000, 64, 'sha512').toString('hex');
  return this.passwordHash === hash;
};

module.exports = mongoose.model('User', userSchema);
