/**
 * Market Scan DB Seeder
 * Run: node seed.js
 * Seeds the marketscan database with sample products and one test supplier
 */
require('dotenv').config();
const mongoose = require('mongoose');
const Product = require('./models/Product');
const Supplier = require('./models/Supplier');
const Transaction = require('./models/Transaction');

const sampleProducts = [
  {
    barcodeId: '6221007001045',
    name: 'بيبسي كولا 330مل',
    category: 'مشروبات',
    sellingPrice: 15,
    costPrice: 10,
    currentStock: 48,
    minThreshold: 12,
  },
  {
    barcodeId: '6224000521098',
    name: 'مياه سافي 1.5 لتر',
    category: 'مشروبات',
    sellingPrice: 8,
    costPrice: 5,
    currentStock: 120,
    minThreshold: 24,
  },
  {
    barcodeId: '6221214710085',
    name: 'شيبسي مالح كبير',
    category: 'سناكس',
    sellingPrice: 12,
    costPrice: 8,
    currentStock: 9,
    minThreshold: 15,
  },
  {
    barcodeId: '6221002300022',
    name: 'أرز شعلان 1 كجم',
    category: 'حبوب',
    sellingPrice: 32,
    costPrice: 25,
    currentStock: 35,
    minThreshold: 10,
  },
  {
    barcodeId: '6225000034567',
    name: 'زيت عافية لتر',
    category: 'زيوت',
    sellingPrice: 55,
    costPrice: 45,
    currentStock: 4,
    minThreshold: 10,
  },
  {
    barcodeId: '6221006501023',
    name: 'نسكافيه كلاسيك 200جم',
    category: 'قهوة وشاي',
    sellingPrice: 85,
    costPrice: 70,
    currentStock: 22,
    minThreshold: 8,
  },
  {
    barcodeId: '6224001700419',
    name: 'معجون أسنان كولجيت 120مل',
    category: 'منظفات شخصية',
    sellingPrice: 25,
    costPrice: 18,
    currentStock: 30,
    minThreshold: 10,
  },
  {
    barcodeId: '7622202330643',
    name: 'تراي دنت عيدان',
    category: 'سناكس',
    sellingPrice: 20,
    costPrice: 15,
    currentStock: 50,
    minThreshold: 10,
  },
];

const sampleSuppliers = [
  {
    name: 'موزع المشروبات الوطنية',
    phone: '+201001234567',
    categories: ['مشروبات'],
    whatsappEnabled: true,
  },
  {
    name: 'شركة البيكو للمواد الغذائية',
    phone: '+201112345678',
    categories: ['سناكس', 'حبوب'],
    whatsappEnabled: true,
  },
];

async function seed() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('✅ Connected to MongoDB:', process.env.MONGODB_URI);

    // Clear existing data
    await Product.deleteMany({});
    await Supplier.deleteMany({});
    await Transaction.deleteMany({});
    console.log('🗑️  Cleared existing data');

    // Insert products
    const products = await Product.insertMany(sampleProducts);
    console.log(`📦 Inserted ${products.length} products`);

    // Insert suppliers
    const suppliers = await Supplier.insertMany(sampleSuppliers);
    console.log(`🏭 Inserted ${suppliers.length} suppliers`);

    // Insert a sample transaction
    await Transaction.create({
      receiptNumber: 'REC-' + Date.now(),
      items: [
        { barcodeId: '6221007001045', name: 'بيبسي كولا 330مل', qty: 2, unitPrice: 15, lineTotal: 30 },
        { barcodeId: '6224000521098', name: 'مياه سافي 1.5 لتر', qty: 1, unitPrice: 8, lineTotal: 8 },
      ],
      totalAmount: 43.32, // includes 14% tax
      paymentMethod: 'نقداً',
    });
    console.log('🧾 Inserted 1 sample transaction');

    console.log('\n🎉 Database seeded successfully!');
    console.log('📊 Open MongoDB Compass and refresh — you will see "marketscan" database');
    console.log('   Collections: products, suppliers, transactions');

    await mongoose.disconnect();
    process.exit(0);
  } catch (err) {
    console.error('❌ Seed error:', err.message);
    process.exit(1);
  }
}

seed();
