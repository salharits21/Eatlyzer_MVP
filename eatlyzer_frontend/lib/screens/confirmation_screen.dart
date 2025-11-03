// === lib/screens/confirmation_screen.dart ===

import 'package:flutter/material.dart';
import 'package:eatlyzer_frontend/main.dart'; // Import main.dart untuk akses warna

class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Menerima argumen (hasil tebakan AI) dari layar sebelumnya
    final String foodName =
        ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konfirmasi Makanan'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Placeholder untuk gambar
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.image_search,
                size: 100,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Kami mendeteksi ini sebagai:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              foodName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Perkiraan: 450 Kkal, 15g Protein, 50g Karbo, 20g Lemak', // Data palsu
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
            ),
            const Spacer(), // Mendorong tombol ke bawah

            // Tombol Aksi
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: MyApp.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                // TODO: Simpan data ke database
                
                // Kembali ke dashboard (menghapus tumpukan layar scan & konfirmasi)
                Navigator.popUntil(context, ModalRoute.withName('/'));
              },
              child: const Text(
                'Ya, Tambahkan ke Jurnal',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              onPressed: () {
                // Pindah ke layar pencarian manual
                Navigator.pushReplacementNamed(context, '/search');
              },
              child: const Text(
                'Bukan, Cari Manual',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}