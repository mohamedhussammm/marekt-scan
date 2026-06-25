/**
 * Market Scan DB Product Importer
 * Run: node import-products.js
 * Imports products from the raw egyptian_products_arabic.csv file into the database on-the-fly.
 */
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const fastcsv = require('fast-csv');
const Product = require('./models/Product');

const CSV_FILE = path.join(__dirname, '..', 'egyptian_products_arabic.csv');

async function importProducts() {
  try {
    // 1. Connect to database
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('✅ Connected to MongoDB:', process.env.MONGODB_URI);

    if (!fs.existsSync(CSV_FILE)) {
      console.error(`❌ CSV File not found at: ${CSV_FILE}`);
      process.exit(1);
    }

    console.log('📖 Reading CSV file and cleaning products on-the-fly...');
    const bulkOps = [];
    let totalRows = 0;
    let skippedRows = 0;

    const stream = fs.createReadStream(CSV_FILE);
    
    // Parse CSV file
    const parser = fastcsv.parse({ headers: true })
      .on('data', (row) => {
        const barcode = row.barcode ? row.barcode.trim() : '';
        const name = row.name ? row.name.trim() : '';

        // On-the-fly cleaning rules:
        // - Skip empty barcodes or names
        // - Skip placeholders where name equals barcode
        // - Skip names that are purely numeric (invalid product names)
        if (!barcode || !name || name === barcode || /^\d+$/.test(name)) {
          skippedRows++;
          return;
        }

        totalRows++;
        
        // Add updateOne bulk operation
        bulkOps.push({
          updateOne: {
            filter: { barcodeId: barcode },
            update: {
              $set: {
                name: name,
                category: 'عام' // Default category to satisfy mongoose validator
              }
            },
            upsert: true
          }
        });
      })
      .on('end', async () => {
        console.log(`Parsed ${totalRows} valid products (skipped ${skippedRows} empty/invalid rows).`);
        
        if (bulkOps.length === 0) {
          console.log('⚠️ No products to import.');
          await mongoose.disconnect();
          process.exit(0);
        }

        console.log('📦 Executing bulk database write operations (this may take a few seconds)...');
        
        // Execute bulk write in batches of 1000 to optimize memory/speed
        const batchSize = 1000;
        let processed = 0;
        
        for (let i = 0; i < bulkOps.length; i += batchSize) {
          const batch = bulkOps.slice(i, i + batchSize);
          const result = await Product.bulkWrite(batch);
          processed += batch.length;
          console.log(`   Processed ${processed}/${bulkOps.length} products...`);
        }

        console.log('\n🎉 Import completed successfully!');
        console.log(`✨ Total products processed/saved: ${bulkOps.length}`);
        
        await mongoose.disconnect();
        process.exit(0);
      })
      .on('error', async (error) => {
        console.error('❌ Error reading CSV:', error);
        await mongoose.disconnect();
        process.exit(1);
      });

    stream.pipe(parser);

  } catch (err) {
    console.error('❌ Database connection or processing error:', err.message);
    process.exit(1);
  }
}

importProducts();
