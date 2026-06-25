const express = require('express');
const router = express.Router();
const User = require('../models/User');
const jwt = require('jsonwebtoken');
const { JWT_SECRET } = require('../middleware/jwt');

// Register
router.post('/register', async (req, res) => {
  try {
    const { username, password, email, storeName, role } = req.body;
    if (!username || !password) {
      return res.status(400).json({ success: false, error: 'اسم المستخدم وكلمة المرور مطلوبان' });
    }

    const existingUser = await User.findOne({ username });
    if (existingUser) {
      return res.status(400).json({ success: false, error: 'اسم المستخدم مسجل بالفعل' });
    }

    // Role Escalation Prevention:
    // Check if any user already exists for this store name.
    // If not, this user is the owner/admin. If yes, this user MUST be a cashier.
    const normalizedStoreName = (storeName || 'سوبر ماركت النيل').trim();
    const existingStoreUsers = await User.countDocuments({ storeName: normalizedStoreName });
    
    let assignedRole = 'cashier';
    if (existingStoreUsers === 0) {
      // First user of the store can be owner or admin
      assignedRole = (role === 'admin' || role === 'owner') ? role : 'owner';
    } else {
      // Subsequent users of this store are strictly cashiers
      assignedRole = 'cashier';
    }

    const newUser = new User({
      username: username.trim(),
      email: email || '',
      storeName: normalizedStoreName,
      role: assignedRole
    });
    newUser.setPassword(password);
    await newUser.save();

    // Generate JWT token on registration
    const token = jwt.sign(
      {
        userId: newUser._id,
        username: newUser.username,
        storeName: newUser.storeName,
        role: newUser.role
      },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(201).json({
      success: true,
      message: 'تم تسجيل المستخدم بنجاح',
      token,
      user: {
        id: newUser._id,
        username: newUser.username,
        storeName: newUser.storeName,
        role: newUser.role
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Login
router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({ success: false, error: 'اسم المستخدم وكلمة المرور مطلوبان' });
    }

    // Lookup user by either username or email
    const user = await User.findOne({
      $or: [ { username: username.trim() }, { email: username.trim() } ]
    });

    if (!user || !user.validPassword(password)) {
      return res.status(400).json({ success: false, error: 'اسم المستخدم أو البريد الإلكتروني أو كلمة المرور غير صحيحة' });
    }

    // Dynamic Hashing Migration: upgrade iterations if below threshold (600,000)
    if (!user.iterations || user.iterations < 600000) {
      user.setPassword(password);
      await user.save();
    }

    // Generate JWT token on login
    const token = jwt.sign(
      {
        userId: user._id,
        username: user.username,
        storeName: user.storeName,
        role: user.role
      },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      success: true,
      message: 'تم تسجيل الدخول بنجاح',
      token,
      user: {
        id: user._id,
        username: user.username,
        storeName: user.storeName,
        role: user.role
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;

