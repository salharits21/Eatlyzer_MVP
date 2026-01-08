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
