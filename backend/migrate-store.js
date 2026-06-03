require('dotenv').config();
const mongoose = require('mongoose');

async function runMigration() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('✅ Connected to MongoDB for migration');

    const db = mongoose.connection.db;

    // Get existing products before we touch anything
    const products = await db.collection('products').find({}).toArray();
    console.log(`🔍 Found ${products.length} products to migrate`);

    for (const p of products) {
      // 1. Insert/update into products catalog (Product collection)
      // Note: we want to keep barcodeId, name, category, but remove sellingPrice, etc.
      await db.collection('products').updateOne(
        { barcodeId: p.barcodeId },
        {
          $set: {
            name: p.name,
            category: p.category
          },
          $unset: {
            sellingPrice: "",
            costPrice: "",
            currentStock: "",
            minThreshold: ""
          }
        }
      );

      // 2. Insert/update into storeinventories (StoreInventory collection)
      await db.collection('storeinventories').updateOne(
        { storeName: 'سوبر ماركت النيل', barcodeId: p.barcodeId },
        {
          $set: {
            sellingPrice: p.sellingPrice || 0,
            costPrice: p.costPrice || 0,
            currentStock: p.currentStock || 0,
            minThreshold: p.minThreshold || 10
          }
        },
        { upsert: true }
      );
      
      console.log(`✨ Migrated product: ${p.name} (${p.barcodeId})`);
    }

    // 3. For any existing Transactions, set the default storeName to 'سوبر ماركت النيل'
    const txCount = await db.collection('transactions').countDocuments({ storeName: { $exists: false } });
    if (txCount > 0) {
      await db.collection('transactions').updateMany(
        { storeName: { $exists: false } },
        { $set: { storeName: 'سوبر ماركت النيل' } }
      );
      console.log(`🧾 Scoped ${txCount} historical transactions to "سوبر ماركت النيل"`);
    }

    // 4. For any existing Settings, set the default storeName to 'سوبر ماركت النيل'
    const settingsCount = await db.collection('settings').countDocuments({ storeName: { $exists: false } });
    if (settingsCount > 0) {
      await db.collection('settings').updateMany(
        { storeName: { $exists: false } },
        { $set: { storeName: 'سوبر ماركت النيل' } }
      );
      console.log(`⚙️ Scoped ${settingsCount} settings documents to "سوبر ماركت النيل"`);
    }

    console.log('🎉 Migration completed successfully!');
    await mongoose.disconnect();
    process.exit(0);
  } catch (err) {
    console.error('❌ Migration failed:', err);
    process.exit(1);
  }
}

runMigration();
