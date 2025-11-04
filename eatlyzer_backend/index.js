const express = require('express');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const multer = require('multer');
const cors = require('cors');
require('dotenv').config();

const app = express();
const port = 3000;

app.use(cors());

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const visionModel = genAI.getGenerativeModel({ model: 'gemini-2.0-flash' });

const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

function bufferToGenerativePart(buffer, mimeType) {
  return {
    inlineData: {
      data: buffer.toString('base64'),
      mimeType,
    },
  };
}

/**
 * ===============================================
 * ENDPOINT UTAMA UNTUK ANALISIS MAKANAN
 * ===============================================
 */
app.post('/analyze', upload.single('image'), async (req, res) => {
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

app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});

