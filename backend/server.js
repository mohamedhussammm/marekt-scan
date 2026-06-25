const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const productsRoute = require('./routes/products');
const transactionsRoute = require('./routes/transactions');
const suppliersRoute = require('./routes/suppliers');
const reportsRoute = require('./routes/reports');
const settingsRoute = require('./routes/settings');
const authRoute = require('./routes/auth');
const shiftsRoute = require('./routes/shifts');
const expensesRoute = require('./routes/expenses');
const logsRoute = require('./routes/logs');
const syncRoute = require('./routes/sync');

const app = express();

app.use(cors());
app.use(express.json());

// ── Serverless-safe MongoDB connection caching ─────────────────────────────
// On Vercel each request may run in a new Lambda context. Caching the
// connection object avoids creating a new connection on every cold start.
let cachedConnection = null;
const connectDB = async () => {
  if (cachedConnection && mongoose.connection.readyState === 1) {
    return cachedConnection;
  }
  cachedConnection = await mongoose.connect(process.env.MONGODB_URI);
  return cachedConnection;
};

// Ensure DB is connected before any route handler runs
app.use(async (req, res, next) => {
  try {
    await connectDB();
    next();
  } catch (err) {
    console.error('MongoDB connection error:', err);
    res.status(500).json({ success: false, error: 'Database unavailable' });
  }
});
// ── End DB middleware ──────────────────────────────────────────────────────

const { authenticateToken } = require('./middleware/jwt');

app.use('/api/auth', authRoute);

// Protect all other routes with JWT middleware
app.use(authenticateToken);

app.use('/api/products', productsRoute);
app.use('/api/transactions', transactionsRoute);
app.use('/api/suppliers', suppliersRoute);
app.use('/api/reports', reportsRoute);
app.use('/api/settings', settingsRoute);
app.use('/api/shifts', shiftsRoute);
app.use('/api/expenses', expensesRoute);
app.use('/api/logs', logsRoute);
app.use('/api/sync', syncRoute);

// Local development only — Vercel handles the HTTP server in production
if (require.main === module) {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
}

// Export for Vercel serverless runtime
module.exports = app;
