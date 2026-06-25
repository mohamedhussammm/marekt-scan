const mongoose = require('mongoose');
const crypto = require('crypto');

const userSchema = new mongoose.Schema({
  username: { type: String, required: true, unique: true },
  email: { type: String, default: '' },
  passwordHash: { type: String, required: true },
  salt: { type: String, required: true },
  iterations: { type: Number, required: true, default: 1000 },
  storeName: { type: String, default: 'سوبر ماركت النيل' },
  role: { type: String, default: 'cashier' }
}, { timestamps: true });

const NEW_ITERATIONS = 600000;

// Helper to hash password using Node.js crypto (scrypt/pbkdf2)
userSchema.methods.setPassword = function(password) {
  this.salt = crypto.randomBytes(16).toString('hex');
  this.iterations = NEW_ITERATIONS;
  this.passwordHash = crypto.pbkdf2Sync(password, this.salt, NEW_ITERATIONS, 64, 'sha512').toString('hex');
};

userSchema.methods.validPassword = function(password) {
  const currentIterations = this.iterations || 1000;
  const hash = crypto.pbkdf2Sync(password, this.salt, currentIterations, 64, 'sha512').toString('hex');
  return this.passwordHash === hash;
};

module.exports = mongoose.model('User', userSchema);
