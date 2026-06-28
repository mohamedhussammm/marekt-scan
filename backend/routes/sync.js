const express = require('express');
const router = express.Router();
const Transaction = require('../models/Transaction');
const Expense = require('../models/Expense');
const Product = require('../models/Product');
const StoreInventory = require('../models/StoreInventory');
const Shift = require('../models/Shift');
const Customer = require('../models/Customer');
const salesController = require('../controllers/salesController');

router.post('/batch', async (req, res) => {
  const { operations } = req.body;
  if (!operations || !Array.isArray(operations)) {
    return res.status(400).json({ success: false, error: 'Invalid payload' });
  }

  const results = { synced: [], failed: [] };

  for (const op of operations) {
    try {
      const data = await processOperation(op, req);
      results.synced.push({
        id: op.id,
        receiptNumber: data ? (data.receiptNumber || null) : null,
        cashierName: data ? (data.cashierName || null) : null
      });
    } catch (err) {
      results.failed.push({ id: op.id, error: err.message, retries: op.retries });
    }
  }

  res.json({ success: true, ...results });
});

async function processOperation(op, req) {
  const { type, payload } = op;
  
  // Inject payload body into a mock request object for existing controllers
  const mockReq = {
    ...req,
    body: payload,
  };
  
  const mockRes = {
    status: function (code) {
      this.statusCode = code;
      return this;
    },
    json: function (data) {
      this.data = data;
      if (this.statusCode >= 400) {
        throw new Error(data.error || 'Operation failed');
      }
      return data;
    }
  };

  switch (type) {
    case 'checkout':
      // Reuse salesController
      await salesController.createTransaction(mockReq, mockRes);
      return mockRes.data;

    case 'add_expense':
      return await processExpense(payload, req);

    case 'add_product':
    case 'update_product':
      await processProduct(payload, req, type);
      break;
      
    case 'delete_product':
      await processDeleteProduct(payload, req);
      break;

    case 'update_stock':
      await processStockUpdate(payload, req);
      break;

    case 'add_customer':
      return await processCustomer(payload, req);

    case 'edit_expense':
      return await processEditExpense(payload, req);

    case 'delete_expense':
      return await processDeleteExpense(payload, req);

    default:
      throw new Error(`Unknown operation type: ${type}`);
  }
}

async function processExpense(payload, req) {
  const { amount, description, category, offline_id } = payload;
  
  if (offline_id) {
    const existing = await Expense.findOne({ storeName: req.storeName, offline_id });
    if (existing) return existing; // Idempotent success
  }

  const activeShift = await Shift.findOne({ storeName: req.storeName, status: 'open' });
  
  const expense = new Expense({
    offline_id: offline_id || undefined,
    storeName: req.storeName,
    cashierUsername: req.username || 'unknown',
    shiftId: activeShift ? activeShift._id : null,
    amount: parseFloat(amount),
    category: category || 'أخرى',
    description: description.trim()
  });

  await expense.save();
  return expense;
}

async function processProduct(payload, req, type) {
  const { barcodeId, name, category, sellingPrice, costPrice, currentStock, minThreshold, offline_id } = payload;
  // Product updates naturally idempotent with upsert.
  // Global catalog
  await Product.findOneAndUpdate(
    { barcodeId },
    { $set: { name, category } },
    { new: true, upsert: true }
  );

  // Store inventory
  await StoreInventory.findOneAndUpdate(
    { storeName: req.storeName, barcodeId },
    {
      $set: {
        sellingPrice: sellingPrice !== undefined ? sellingPrice : 0,
        costPrice: costPrice !== undefined ? costPrice : 0,
        currentStock: currentStock !== undefined ? currentStock : 0,
        minThreshold: minThreshold !== undefined ? minThreshold : 10
      }
    },
    { new: true, upsert: true }
  );
}

async function processDeleteProduct(payload, req) {
  const { barcodeId } = payload;
  // Naturally idempotent
  await StoreInventory.findOneAndDelete({ storeName: req.storeName, barcodeId });
}

async function processStockUpdate(payload, req) {
  const { barcodeId, quantity, offline_id } = payload;
  
  // Since we don't have offline_id on StoreInventory, we increment. 
  // However, duplicate stock updates can be an issue. To make it strictly idempotent,
  // we would need an inventory transactions log. For simplicity, we just apply the increment.
  // In a robust system, we should have an InventoryMovement table.
  // We'll rely on the offline_queue being cleared properly.
  
  await StoreInventory.findOneAndUpdate(
    { storeName: req.storeName, barcodeId },
    { $inc: { currentStock: quantity } },
    { new: true, upsert: true }
  );
}

async function processCustomer(payload, req) {
  const { customerId, fullName, phoneNumber, address } = payload;
  if (!customerId || !fullName) {
    throw new Error('معرف العميل والاسم الكامل مطلوبان');
  }

  const existing = await Customer.findOne({ customerId });
  if (existing) return existing;

  const customer = new Customer({
    storeName: req.storeName,
    customerId,
    fullName: fullName.trim(),
    phoneNumber: phoneNumber ? phoneNumber.trim() : '',
    address: address ? address.trim() : ''
  });

  await customer.save();
  return customer;
}

async function processEditExpense(payload, req) {
  const { id, offline_id, amount, description, category } = payload;
  let expense;
  if (id) {
    expense = await Expense.findOne({ _id: id, storeName: req.storeName });
  } else if (offline_id) {
    expense = await Expense.findOne({ offline_id, storeName: req.storeName });
  }
  
  if (expense) {
    expense.amount = parseFloat(amount);
    expense.description = description.trim();
    expense.category = category || 'أخرى';
    await expense.save();
  }
  return expense;
}

async function processDeleteExpense(payload, req) {
  const { id, offline_id } = payload;
  if (id) {
    await Expense.findOneAndDelete({ _id: id, storeName: req.storeName });
  } else if (offline_id) {
    await Expense.findOneAndDelete({ offline_id, storeName: req.storeName });
  }
  return null;
}

module.exports = router;
