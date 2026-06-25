const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'marketscan-fallback-secret-key-32-chars-long';

const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({
      success: false,
      error: 'غير مصرح بالدخول: رمز المصادقة مفقود'
    });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({
        success: false,
        error: 'غير مصرح بالدخول: رمز مصادقة غير صالح أو منتهي الصلاحية'
      });
    }

    // Attach decoded user data to req object
    req.userId = user.userId;
    req.username = user.username;
    req.storeName = user.storeName;
    req.userRole = user.role;
    next();
  });
};

module.exports = {
  authenticateToken,
  JWT_SECRET
};
