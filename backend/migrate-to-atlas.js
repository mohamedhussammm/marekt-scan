/**
 * Migration Script: Local MongoDB → MongoDB Atlas
 * Copies ALL collections from local marketscan DB to Atlas cloud.
 * Run ONCE with: node migrate-to-atlas.js
 */

const mongoose = require('mongoose');

const LOCAL_URI  = 'mongodb://localhost:27017/marketscan';
const ATLAS_URI  = 'mongodb+srv://mohamedhussamhamdy50_db_user:mKEotySU8LucbtTv@market-scan.1wuf82r.mongodb.net/marketscan?retryWrites=true&w=majority&appName=Market-Scan';

// Collections to migrate (add any extra ones if you have them)
const COLLECTIONS = [
  'users',
  'products',
  'storeinventories',
  'transactions',
  'expenses',
  'settings',
  'shifts',
  'suppliers',
  'logs',
];

async function migrate() {
  console.log('\n🔌 Connecting to LOCAL MongoDB...');
  const localConn = await mongoose.createConnection(LOCAL_URI).asPromise();
  console.log('✅ Connected to local DB');

  console.log('\n🔌 Connecting to ATLAS MongoDB...');
  const atlasConn = await mongoose.createConnection(ATLAS_URI).asPromise();
  console.log('✅ Connected to Atlas DB');

  let grandTotal = 0;

  for (const collectionName of COLLECTIONS) {
    try {
      const localCol  = localConn.collection(collectionName);
      const atlasCol  = atlasConn.collection(collectionName);

      const docs = await localCol.find({}).toArray();

      if (docs.length === 0) {
        console.log(`\n⏭️  [${collectionName}] — empty, skipping`);
        continue;
      }

      console.log(`\n📦 [${collectionName}] — found ${docs.length} document(s), migrating...`);

      // Insert in batches of 100 to avoid Atlas limits
      const BATCH = 100;
      let inserted = 0;
      for (let i = 0; i < docs.length; i += BATCH) {
        const batch = docs.slice(i, i + BATCH);
        try {
          // ordered:false so one duplicate doesn't abort the rest
          await atlasCol.insertMany(batch, { ordered: false });
          inserted += batch.length;
        } catch (err) {
          // BulkWriteError 11000 = duplicate key — document already exists, skip
          if (err.code === 11000 || err.name === 'MongoBulkWriteError') {
            const ok = err.result?.nInserted ?? 0;
            inserted += ok;
            console.log(`   ⚠️  ${batch.length - ok} duplicate(s) skipped in batch`);
          } else {
            throw err;
          }
        }
      }

      console.log(`   ✅ ${inserted} document(s) inserted into Atlas`);
      grandTotal += inserted;

    } catch (err) {
      console.error(`   ❌ Error migrating [${collectionName}]:`, err.message);
    }
  }

  console.log(`\n🎉 Migration complete! Total documents migrated: ${grandTotal}`);

  await localConn.close();
  await atlasConn.close();
  console.log('🔒 Both connections closed.\n');
  process.exit(0);
}

migrate().catch((err) => {
  console.error('\n💥 Fatal migration error:', err.message);
  process.exit(1);
});
