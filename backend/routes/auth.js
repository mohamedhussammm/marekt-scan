const express = require('express');
const router = express.Router();
const User = require('../models/User');

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

    const newUser = new User({
      username,
      email: email || '',
      storeName: storeName || 'سوبر ماركت النيل',
      role: role || 'cashier'
    });
    newUser.setPassword(password);
    await newUser.save();

    res.status(201).json({
      success: true,
      message: 'تم تسجيل المستخدم بنجاح',
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

    // Dynamic fallback: if database has zero users, auto-seed a default admin user
    // Dynamic lookup by either username or email
    let user = await User.findOne({
      $or: [ { username: username }, { email: username } ]
    });

    if (!user && (await User.countDocuments()) === 0 && username === 'admin') {
      const newUser = new User({
        username: 'admin',
        email: 'admin@marketscan.com',
        storeName: 'سوبر ماركت النيل',
        role: 'admin'
      });
      newUser.setPassword('admin123');
      await newUser.save();
      user = newUser;
    }

    if (!user || !user.validPassword(password)) {
      return res.status(400).json({ success: false, error: 'اسم المستخدم أو البريد الإلكتروني أو كلمة المرور غير صحيحة' });
    }

    res.json({
      success: true,
      message: 'تم تسجيل الدخول بنجاح',
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
