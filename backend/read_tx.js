const mongoose = require('mongoose');
const MONGODB_URI = 'mongodb+srv://mohamedhussamhamdy50_db_user:mKEotySU8LucbtTv@market-scan.1wuf82r.mongodb.net/marketscan?retryWrites=true&w=majority&appName=Market-Scan';

async function run() {
  await mongoose.connect(MONGODB_URI);
  const Transaction = mongoose.model('Transaction', new mongoose.Schema({}, { strict: false }));
  const tx = await Transaction.findOne({ receiptNumber: 'RCP-1781949944360' });
  console.log(JSON.stringify(tx, null, 2));
  await mongoose.disconnect();
}
run();
