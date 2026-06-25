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

const NEW_ITERATIONS = 100000;

// Helper to hash password using Node.js crypto (pbkdf2 async)
userSchema.methods.setPasswordAsync = function(password) {
  return new Promise((resolve, reject) => {
    this.salt = crypto.randomBytes(16).toString('hex');
    this.iterations = NEW_ITERATIONS;
    crypto.pbkdf2(password, this.salt, NEW_ITERATIONS, 64, 'sha512', (err, derivedKey) => {
      if (err) return reject(err);
      this.passwordHash = derivedKey.toString('hex');
      resolve();
    });
  });
};

userSchema.methods.setPassword = function(password) {
  this.salt = crypto.randomBytes(16).toString('hex');
  this.iterations = NEW_ITERATIONS;
  this.passwordHash = crypto.pbkdf2Sync(password, this.salt, NEW_ITERATIONS, 64, 'sha512').toString('hex');
};

userSchema.methods.validPasswordAsync = function(password) {
  const currentIterations = this.iterations || 1000;
  return new Promise((resolve, reject) => {
    crypto.pbkdf2(password, this.salt, currentIterations, 64, 'sha512', (err, derivedKey) => {
      if (err) return reject(err);
      resolve(this.passwordHash === derivedKey.toString('hex'));
    });
  });
};

userSchema.methods.validPassword = function(password) {
  const currentIterations = this.iterations || 1000;
  const hash = crypto.pbkdf2Sync(password, this.salt, currentIterations, 64, 'sha512').toString('hex');
  return this.passwordHash === hash;
};

module.exports = mongoose.model('User', userSchema);
