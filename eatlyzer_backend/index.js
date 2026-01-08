// ================== SETUP ==================
const express = require('express');
const cors = require('cors');
const multer = require('multer');
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const OpenAI = require('openai');
require('dotenv').config();

const app = express();
const port = 3000;

// ================== MIDDLEWARE ==================
app.use(cors());
app.use(express.json());

// ================== DATABASE ==================
const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

pool.query('SELECT NOW()')
  .then(() => console.log('PostgreSQL connected'))
  .catch(err => console.error('PostgreSQL ERROR:', err));

// ================== OPENAI ==================
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// ================== MULTER ==================
const upload = multer({ storage: multer.memoryStorage() });

// ================== AUTH MIDDLEWARE ==================
const authMiddleware = (req, res, next) => {
  const authHeader = req.header('Authorization');
  if (!authHeader) {
    return res.status(401).json({ error: 'Tidak ada token' });
  }

  try {
    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch {
    return res.status(401).json({ error: 'Token tidak valid' });
  }
};

// ================== REGISTER ==================
app.post('/auth/register', async (req, res) => {
  const { name, email, password } = req.body;
  if (!name || !email || !password) {
    return res.status(400).json({ error: 'Data tidak lengkap' });
  }

  try {
    const exists = await pool.query(
      'SELECT id FROM users WHERE email=$1',
      [email]
    );

    if (exists.rows.length > 0) {
      return res.status(400).json({ error: 'Email sudah terdaftar' });
    }

    const hash = await bcrypt.hash(password, 10);

    const result = await pool.query(
      `INSERT INTO users (name, email, password_hash)
       VALUES ($1,$2,$3)
       RETURNING id,name,email`,
      [name, email, hash]
    );

    const user = result.rows[0];
    const token = jwt.sign(
      { userId: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.status(201).json({ token, user });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ================== LOGIN ==================
app.post('/auth/login', async (req, res) => {
  const { email, password } = req.body;

  try {
    const result = await pool.query(
      'SELECT * FROM users WHERE email=$1',
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Login gagal' });
    }

    const user = result.rows[0];
    const valid = await bcrypt.compare(password, user.password_hash);

    if (!valid) {
      return res.status(401).json({ error: 'Login gagal' });
    }

    const token = jwt.sign(
      { userId: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      token,
      user: { id: user.id, name: user.name, email: user.email },
    });
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

// ================== ANALYZE FOOD (OPENAI) ==================
app.post(
  '/analyze',
  authMiddleware,
  upload.single('image'),
  async (req, res) => {
    if (!req.file) {
      return res.status(400).json({ error: 'Image required' });
    }

    try {
      const base64Image = req.file.buffer.toString('base64');

      const prompt = `
Return ONLY valid JSON:
{
 "foodName": "",
 "calories": 0,
 "protein": 0,
 "carbs": 0,
 "fat": 0
}
Estimate nutrition realistically.
`;

      const response = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: 'Return JSON only.' },
          {
            role: 'user',
            content: [
              { type: 'text', text: prompt },
              {
                type: 'image_url',
                image_url: {
                  url: `data:image/jpeg;base64,${base64Image}`,
                },
              },
            ],
          },
        ],
        temperature: 0.2,
      });

      const text = response.choices[0].message.content
        .replace(/```json|```/g, '')
        .trim();

      const data = JSON.parse(text);

      data.imageUrl = `https://placehold.co/600x400?text=${encodeURIComponent(
        data.foodName || 'Food'
      )}`;

      res.json(data);
    } catch (err) {
      console.error('AI ERROR:', err);
      res.status(503).json({
        error: 'AI service unavailable',
      });
    }
  }
);

// ================== SAVE JOURNAL ==================
app.post('/journal', authMiddleware, async (req, res) => {
  const { userId } = req.user;
  const { foodName, imageUrl, calories, protein, carbs, fat } = req.body;

  try {
    const result = await pool.query(
      `INSERT INTO food_entries
       (user_id, food_name, image_url, calories, protein, carbs, fat)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       RETURNING *`,
      [userId, foodName, imageUrl, calories, protein, carbs, fat]
    );

    res.status(201).json(result.rows[0]);
  } catch {
    res.status(500).json({ error: 'DB error' });
  }
});

// ================== DASHBOARD ==================
app.get('/journal/today', authMiddleware, async (req, res) => {
  const { userId } = req.user;

  try {
    const [user, summary, entries] = await Promise.all([
      pool.query('SELECT name FROM users WHERE id=$1', [userId]),
      pool.query(
        `SELECT
         COALESCE(SUM(calories),0) calories,
         COALESCE(SUM(protein),0) protein,
         COALESCE(SUM(carbs),0) carbs,
         COALESCE(SUM(fat),0) fat
         FROM food_entries
         WHERE user_id=$1 AND DATE(created_at)=CURRENT_DATE`,
        [userId]
      ),
      pool.query(
        `SELECT * FROM food_entries
         WHERE user_id=$1 AND DATE(created_at)=CURRENT_DATE
         ORDER BY created_at DESC`,
        [userId]
      ),
    ]);

    res.json({
      user: user.rows[0],
      summary: summary.rows[0],
      entries: entries.rows,
    });
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
});

// ================== START ==================
app.listen(port, '0.0.0.0', () => {
  console.log(`Server running on http://0.0.0.0:${port}`);
});

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

// ================== OPENAI ==================
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// ================== MULTER ==================
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
      Return ONLY valid JSON:
      {
      "foodName": "",
      "calories": 0,
      "protein": 0,
      "carbs": 0,
      "fat": 0
      }
      Estimate nutrition realistically.
    `;

    const imagePart = bufferToGenerativePart(req.file.buffer, 'image/jpeg');

    const result = await visionModel.generateContent([prompt, imagePart]);
    const responseText = result.response.text();

    console.log('Respon dari Gemini:', responseText);

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
  const { userId } = req.user;
  const { foodName, imageUrl, calories, protein, carbs, fat } = req.body;

  if (!foodName || calories == null) {
    return res.status(400).json({ error: 'Data makanan tidak lengkap.' });
  }

  try {
    // 1. Simpan makanan (Kode Lama)
    const newEntry = await pool.query(
      `INSERT INTO food_entries (user_id, food_name, image_url, calories, protein, carbs, fat)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [userId, foodName, imageUrl, calories, protein, carbs, fat]
    );

    // --- LOGIKA BARU: Cek Target/Batas ---
    
    // 2. Hitung total hari ini setelah penambahan
    const summaryQuery = await pool.query(
      `SELECT 
         COALESCE(SUM(calories), 0) as total_calories,
         COALESCE(SUM(protein), 0) as total_protein,
         COALESCE(SUM(carbs), 0) as total_carbs,
         COALESCE(SUM(fat), 0) as total_fat
       FROM food_entries 
       WHERE user_id = $1 AND DATE(created_at) = CURRENT_DATE`,
      [userId]
    );
    const summary = summaryQuery.rows[0];

    // 3. Ambil target user
    const goalQuery = await pool.query('SELECT * FROM user_goals WHERE user_id = $1', [userId]);
    const goal = goalQuery.rows[0];

    let alertMessage = null;
    let alertType = null; // 'success' (Target Reached) atau 'warning' (Limit Exceeded)

    if (goal) {
      // Logika CUTTING (Batas/Limit)
      if (goal.goal_type === 'limit') {
        if (summary.total_calories > goal.calories_goal) {
          alertType = 'warning';
          alertMessage = 'Peringatan! Asupan kalori Anda telah melewati batas harian.';
        } 
        // Anda bisa menambahkan 'else if' untuk protein/carbs/fat jika ingin spesifik
      } 
      // Logika BULKING (Target)
      else if (goal.goal_type === 'target') {
        // Cek apakah baru saja mencapai target (Logic sederhana: jika total >= target)
        // Idealnya kita cek apakah 'total - current_input' < target, tapi ini cukup untuk MVP
        if (summary.total_calories >= goal.calories_goal) {
          alertType = 'success';
          alertMessage = 'Selamat! Anda telah mencapai target kalori harian.';
        }
      }
    }

    // 4. Kirim respon + Alert Info
    res.status(201).json({
      message: 'Data berhasil disimpan',
      entry: newEntry.rows[0],
      alert: alertMessage ? { type: alertType, message: alertMessage } : null
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

// ===============================================
// 6. ENDPOINT GOALS: SET/UPDATE TARGET
// ===============================================
app.post('/user/goals', authMiddleware, async (req, res) => {
  const { userId } = req.user;
  const { goalType, calories, protein, carbs, fat } = req.body;

  try {
    // Upsert (Insert jika belum ada, Update jika sudah ada)
    const query = `
      INSERT INTO user_goals (user_id, goal_type, calories_goal, protein_goal, carbs_goal, fat_goal)
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (user_id) 
      DO UPDATE SET 
        goal_type = EXCLUDED.goal_type,
        calories_goal = EXCLUDED.calories_goal,
        protein_goal = EXCLUDED.protein_goal,
        carbs_goal = EXCLUDED.carbs_goal,
        fat_goal = EXCLUDED.fat_goal
      RETURNING *;
    `;
    
    const result = await pool.query(query, [userId, goalType, calories, protein, carbs, fat]);
    res.json({ message: 'Target berhasil disimpan', goal: result.rows[0] });
  } catch (error) {
    console.error('Error setting goals:', error);
    res.status(500).json({ error: 'Gagal menyimpan target.' });
  }
});

// ===============================================
// 7. ENDPOINT GOALS: GET TARGET (Untuk ditampilkan di UI)
// ===============================================
app.get('/user/goals', authMiddleware, async (req, res) => {
  const { userId } = req.user;
  try {
    const result = await pool.query('SELECT * FROM user_goals WHERE user_id = $1', [userId]);
    // Jika belum ada setting, kembalikan default null
    res.json(result.rows[0] || null);
  } catch (error) {
    res.status(500).json({ error: 'Gagal mengambil data target.' });
  }
});