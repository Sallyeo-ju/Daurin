require('dotenv').config();
const express = require('express');
const axios = require('axios');
const app = express();

app.use(express.json());

// Endpoint backend kamu yang akan dipanggil oleh Flutter
app.post('/api/cek-ongkir', async (req, res) => {
  try {
    // 1. Ambil data yang dikirim dari aplikasi Flutter (misal: asal, tujuan, berat)
    const { origin, destination, weight } = req.body;

    // 2. Tembak API Komerce (Domestic-Cost)
    const response = await axios.post(
      `${process.env.KOMERCE_BASE_URL}/shipping/domestic-cost`, // Sesuaikan endpoint dengan dokumentasi API
      {
        origin: origin,
        destination: destination,
        weight: weight
      },
      {
        headers: {
          // Masukkan API Key di sini. Cek dokumentasi Komerce apakah menggunakan format Bearer atau Custom Header
          'Authorization': `Bearer ${process.env.KOMERCE_API_KEY}`,
          'Content-Type': 'application/json'
        }
      }
    );

    // 3. Kembalikan hasil dari Komerce ke aplikasi Flutter
    res.status(200).json({
      success: true,
      data: response.data
    });

  } catch (error) {
    console.error("Error cek ongkir:", error.response?.data || error.message);
    res.status(500).json({
      success: false,
      message: 'Gagal mengambil data ongkos kirim'
    });
  }
});

app.listen(3000, () => console.log('Server berjalan di port 3000'));