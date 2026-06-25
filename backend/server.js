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
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

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

mongoose.connect(process.env.MONGODB_URI)
  .then(() => {
    console.log('Connected to MongoDB');
    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });
  })
  .catch((err) => {
    console.error('MongoDB connection error:', err);
  });
