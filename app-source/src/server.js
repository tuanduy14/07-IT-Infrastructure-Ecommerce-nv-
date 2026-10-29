const express = require('express');
const { Pool } = require('pg');

const app = express();
app.use(express.json());

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  database: process.env.DB_NAME || 'ecommerce_db',
});

// Hàm thử kết nối lại với Database nếu chưa sẵn sàng
const connectWithRetry = () => {
  pool.query('SELECT NOW()')
    .then(() => {
      console.log(' kết nối Database thành công!');
      initializeDatabase();
    })
    .catch(err => {
      console.log('⏳ Database chưa sẵn sàng, đang thử lại sau 3 giây...', err.message);
      setTimeout(connectWithRetry, 3000);
    });
};

// Hàm tạo bảng và dữ liệu mẫu
const initializeDatabase = async () => {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS products (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100),
        price NUMERIC
      );
      CREATE TABLE IF NOT EXISTS orders (
        id SERIAL PRIMARY KEY,
        product_id INT,
        quantity INT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    const res = await pool.query(`SELECT COUNT(*) FROM products;`);
    if (parseInt(res.rows[0].count) === 0) {
      await pool.query(`
        INSERT INTO products (name, price) VALUES 
        ('Laptop Gaming', 1200.00),
        ('Chuột không dây', 25.50),
        ('Bàn phím cơ', 75.00);
      `);
      console.log(' Đã chèn dữ liệu mẫu vào bảng products.');
    }
  } catch (err) {
    console.error('Lỗi khởi tạo bảng Database:', err);
  }
};

// Bắt đầu quá trình kết nối
connectWithRetry();

// API 1: Đọc danh mục sản phẩm (Read)
app.get('/api/products', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM products');
    res.json({ success: true, data: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// API 2: Ghi đơn hàng mới (Write)
app.post('/api/orders', async (req, res) => {
  const { product_id, quantity } = req.body;
  try {
    const result = await pool.query(
      'INSERT INTO orders (product_id, quantity) VALUES ($1, $2) RETURNING *',
      [product_id, quantity || 1]
    );
    res.status(201).json({ success: true, order: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`App đang chạy tại cổng ${PORT}`);
});