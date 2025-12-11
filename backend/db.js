require('dotenv').config();
const mysql = require('mysql2');

const db = mysql.createConnection({
  host: process.env.DB_HOST || 'mysql',
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  // If MySQL server generates self-signed certs, allow them (internal network)
  ssl: { rejectUnauthorized: false }
});

db.connect((err) => {
  if(err) {
    console.error('❌ Database connection failed:', err);
    process.exit(1);
  }
  console.log('✅ MySQL Connected Successfully!');
});

module.exports = db;
