const SecurityLog = require('../models/SecurityLog');

const checkOwner = async (req, res, next) => {
  const role = req.userRole || 'cashier';
  if (role !== 'admin' && role !== 'owner') {
    try {
      const log = new SecurityLog({
        username: req.username || 'unknown',
        storeName: req.storeName || 'unknown',
        action: 'UNAUTHORIZED_ACCESS_ATTEMPT',
        details: `User attempted to access restricted admin route: ${req.method} ${req.originalUrl}`
      });
      await log.save();
      console.warn(`[SECURITY VIOLATION] User ${req.username} attempted to access restricted endpoint ${req.method} ${req.originalUrl}`);
    } catch (err) {
      console.error('Failed to log security violation:', err);
    }

    return res.status(403).json({
      success: false,
      error: 'غير مسموح بالدخول: صلاحيات مالك المتجر مطلوبة لإجراء هذه العملية'
    });
  }
  next();
};

module.exports = { checkOwner };
