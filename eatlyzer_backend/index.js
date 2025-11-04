// === index.js (Backend) ===

const express = require('express');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const multer = require('multer');
const cors = require('cors');
const { Pool } = require('pg'); // <-- Import PG
const bcrypt = require('bcryptjs'); // <-- Import Bcrypt
const jwt = require('jsonwebtoken'); // <-- Import JWT
require('dotenv').config();

const app = express();
const port = 3000;

// --- Middleware ---
app.use(cors());
app.use(express.json()); // <-- PENTING: Untuk parsing body JSON

// --- Konfigurasi Database (PostgreSQL) ---
const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

// --- Konfigurasi Gemini & Multer (Sudah Ada) ---
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const visionModel = genAI.getGenerativeModel({ model: 'gemini-2.0-flash' }); 
const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

// --- Helper untuk Konversi Buffer (Sudah Ada) ---
function bufferToGenerativePart(buffer, mimeType) {
  return {
    inlineData: {
      data: buffer.toString('base64'),
      mimeType,
    },
  };
}

// ===============================================
// MIDDLEWARE OTENTIKASI (PENJAGA GERBANG)
// ===============================================
const authMiddleware = (req, res, next) => {
  // 1. Ambil header Authorization
  const authHeader = req.header('Authorization');

  // 2. Cek jika header tidak ada
  if (!authHeader) {
    return res.status(401).json({ error: 'Akses ditolak. Tidak ada token.' });
  }

  try {
    // 3. Ambil token dari header (format: "Bearer <token>")
    const token = authHeader.split(' ')[1];
    if (!token) {
      return res.status(401).json({ error: 'Format token salah.' });
    }

    // 4. Verifikasi token
    const decoded = jwt.verify(
      token,
      process.env.JWT_SECRET || 'rahasia-banget-ini'
    );

    // 5. Simpan data user ke 'req' agar bisa dipakai di endpoint
    req.user = decoded; // Ini akan berisi { userId, email }
    
    // 6. Lanjutkan ke fungsi endpoint (misal: logika /analyze)
    next();
  } catch (error) {
    // Token tidak valid (kadaluarsa, salah, dll)
    res.status(401).json({ error: 'Token tidak valid.' });
  }
};

// ===============================================
// 1. ENDPOINT OTENTIKASI: REGISTER
// ===============================================
app.post('/auth/register', async (req, res) => {
  const { name, email, password } = req.body;

  // Validasi dasar
  if (!email || !password || !name) {
    return res.status(400).json({ error: 'Nama, email, dan password diperlukan.' });
  }

  try {
    // 1. Cek apakah email sudah terdaftar
    const userCheck = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (userCheck.rows.length > 0) {
      return res.status(400).json({ error: 'Email sudah terdaftar.' });
    }

    // 2. Hash password
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    // 3. Simpan user baru
    const newUser = await pool.query(
      'INSERT INTO users (name, email, password_hash) VALUES ($1, $2, $3) RETURNING id, name, email',
      [name, email, passwordHash]
    );

    const user = newUser.rows[0];

    // 4. Buat Token (JWT)
    const token = jwt.sign(
      { userId: user.id, email: user.email },
      process.env.JWT_SECRET || 'rahasia-banget-ini', // Ganti dengan secret acak di .env
      { expiresIn: '30d' }
    );

    // 5. Kirim respon
    res.status(201).json({
      message: 'Registrasi berhasil',
      token,
      user: { id: user.id, name: user.name, email: user.email },
    });
  } catch (error) {
    console.error('Error register:', error);
    res.status(500).json({ error: 'Terjadi kesalahan server.' });
  }
});

// ===============================================
// 2. ENDPOINT OTENTIKASI: LOGIN
// ===============================================
app.post('/auth/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'Email dan password diperlukan.' });
  }

  try {
    // 1. Cari user berdasarkan email
    const userResult = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (userResult.rows.length === 0) {
      return res.status(401).json({ error: 'Email atau password salah.' });
    }

    const user = userResult.rows[0];

    // 2. Bandingkan password
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({ error: 'Email atau password salah.' });
    }

    // 3. Buat Token (JWT)
    const token = jwt.sign(
      { userId: user.id, email: user.email },
      process.env.JWT_SECRET || 'rahasia-banget-ini',
      { expiresIn: '30d' }
    );

    // 4. Kirim respon
    res.json({
      message: 'Login berhasil',
      token,
      user: { id: user.id, name: user.name, email: user.email },
    });
  } catch (error) {
    console.error('Error login:', error);
    res.status(500).json({ error: 'Terjadi kesalahan server.' });
  }
});

// ===============================================
// 3. ENDPOINT ANALISIS MAKANAN (Sudah Ada)
// ===============================================
app.post('/analyze', authMiddleware, upload.single('image'), async (req, res) => {
  // ... (Kode endpoint /analyze Anda yang sudah ada, tidak perlu diubah) ...
  // ... (pastikan prompt Anda masih dalam mode simulasi) ...

  console.log('Menerima request analisis (Mode Simulasi)...');

  if (!req.file) {
    return res.status(400).json({ error: 'Tidak ada file gambar yang di-upload.' });
  }

  try {
    const prompt = `
      INI UNTUK SIMULASI DEMO.
      Abaikan apa pun yang ada di dalam gambar.
      Tugas Anda adalah SELALU mengembalikan data makanan, bahkan jika gambar itu bukan makanan (seperti pemandangan atau gambar virtual).
      
      Pilih satu nama makanan yang umum secara acak (misalnya: 'Nasi Goreng', 'Ayam Bakar', 'Salad Buah', 'Burger Keju', 'Sepiring Apel').
      Berikan perkiraan nutrisi yang wajar untuk makanan acak tersebut.
      
      Kembalikan HANYA sebuah objek JSON dengan format berikut, tanpa teks tambahan atau markdown ('''json ... '''):
      {
        "foodName": "Nama Makanan Acak",
        "calories": 0, 
        "protein": 0,
        "carbs": 0,
        "fat": 0
      }
    `;

    const imagePart = bufferToGenerativePart(req.file.buffer, 'image/jpeg');

    const result = await visionModel.generateContent([prompt, imagePart]);
    const responseText = result.response.text();

    console.log('Respon Simulasi dari Gemini:', responseText);

    const cleanedText = responseText
      .replace(/```json/g, '')
      .replace(/```/g, '')
      .trim();

    const jsonResponse = JSON.parse(cleanedText);

    if (jsonResponse.foodName) {
      jsonResponse.imageUrl = `https://placehold.co/600x400/E2E8F0/4A5568?text=${encodeURIComponent(jsonResponse.foodName)}`;
    } else {
      jsonResponse.imageUrl = 'https://placehold.co/600x400/E2E8F0/4A5568?text=Makanan';
    }

    res.json(jsonResponse);
  } catch (error) {
    console.error('Error saat analisis Gemini:', error);
    res.status(500).json({ error: 'Terjadi kesalahan di server.' });
  }
});

// ===============================================
// 4. ENDPOINT JURNAL: TAMBAH ENTRI BARU
// ===============================================
app.post('/journal', authMiddleware, async (req, res) => {
  // 1. Ambil data user dari token (via middleware)
  const { userId } = req.user;

  // 2. Ambil data makanan dari body request
  // (Data ini dikirim dari confirmation_screen.dart)
  const { foodName, imageUrl, calories, protein, carbs, fat } = req.body;

  // 3. Validasi dasar
  if (
    !foodName ||
    calories == null ||
    protein == null ||
    carbs == null ||
    fat == null
  ) {
    return res.status(400).json({ error: 'Data makanan tidak lengkap.' });
  }

  try {
    // 4. Simpan ke database
    const newEntry = await pool.query(
      `INSERT INTO food_entries (user_id, food_name, image_url, calories, protein, carbs, fat)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`, // RETURNING * mengembalikan data yg baru di-insert
      [userId, foodName, imageUrl, calories, protein, carbs, fat]
    );

    // 5. Kirim respon sukses (201 Created)
    res.status(201).json({
      message: 'Data berhasil disimpan',
      entry: newEntry.rows[0],
    });
  } catch (error) {
    console.error('Error saat menyimpan ke jurnal:', error);
    res.status(500).json({ error: 'Terjadi kesalahan server.' });
  }
});

// ===============================================
// 5. ENDPOINT DASHBOARD: GET JURNAL HARI INI
// ===============================================
app.get('/journal/today', authMiddleware, async (req, res) => {
  // Ambil userId dari token yang sudah divalidasi
  const { userId } = req.user;

  try {
    // Kita akan menjalankan 3 kueri secara bersamaan untuk efisiensi
    // menggunakan Promise.all

    // Kueri 1: Get data pengguna (untuk menyapa "Hi, [Nama]")
    const userQuery = pool.query(
      `SELECT name, email FROM users WHERE id = $1`, 
      [userId]
    );

    // Kueri 2: Get ringkasan nutrisi (total kalori, protein, dll)
    const summaryQuery = pool.query(
      `SELECT 
         COALESCE(SUM(calories), 0) as total_calories, 
         COALESCE(SUM(protein), 0) as total_protein, 
         COALESCE(SUM(carbs), 0) as total_carbs, 
         COALESCE(SUM(fat), 0) as total_fat 
       FROM food_entries 
       WHERE user_id = $1 AND DATE(created_at) = CURRENT_DATE`,
      [userId]
    );

    // Kueri 3: Get daftar makanan yang dimakan hari ini
    const entriesQuery = pool.query(
      `SELECT id, food_name, calories, created_at 
       FROM food_entries 
       WHERE user_id = $1 AND DATE(created_at) = CURRENT_DATE 
       ORDER BY created_at DESC`,
      [userId]
    );

    // Jalankan semua kueri
    const [userResult, summaryResult, entriesResult] = await Promise.all([
      userQuery,
      summaryQuery,
      entriesQuery,
    ]);

    // Kirim semua data dalam satu paket JSON
    res.json({
      user: userResult.rows[0] || { name: 'Pengguna' },
      summary: summaryResult.rows[0],
      entries: entriesResult.rows,
    });
  } catch (error) {
    console.error('Error saat mengambil data dashboard:', error);
    res.status(500).json({ error: 'Terjadi kesalahan server.' });
  }
});

// --- Server Start ---
app.listen(port, '0.0.0.0', () => { // <-- Tambahkan '0.0.0.0' agar bisa diakses dari HP
  console.log(`Server running on http://0.0.0.0:${port}`);
});