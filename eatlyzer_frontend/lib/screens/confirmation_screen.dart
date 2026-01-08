import 'dart:convert';
import 'dart:io';

import 'package:eatlyzer_frontend/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:eatlyzer_frontend/main.dart';
import 'package:http/http.dart' as http;

class ConfirmationScreen extends StatefulWidget {
  const ConfirmationScreen({super.key});

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  final SecureStorageService _storageService = SecureStorageService();
  bool _isLoading = false;

  // Fungsi baru untuk menyimpan ke jurnal
  Future<void> _saveToJournal(Map<String, dynamic> nutritionData) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Ambil data backend (URL & Token)
      final String baseUrl = await _storageService.getBaseUrl();
      final String? token = await _storageService.readToken();

      if (token == null) {
        _showError('Sesi tidak ditemukan, silakan login kembali.');
        // TODO: Navigasi paksa ke login
        return;
      }

      // 2. Kirim data ke backend
      final response = await http.post(
        Uri.parse('$baseUrl/journal'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Kirim token untuk otentikasi
        },
        body: json.encode(nutritionData), // Kirim semua data nutrisi
      );

      // 3. Proses respon
      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        // === LOGIKA NOTIFIKASI POP UP BARU ===
      if (responseData['alert'] != null) {
        final alert = responseData['alert'];
        
        // Tampilkan Dialog sebelum pindah halaman
        if (mounted) {
           await showDialog(
            context: context,
            barrierDismissible: false, // User harus klik tombol OK
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(
                    alert['type'] == 'success' ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: alert['type'] == 'success' ? Colors.green : Colors.red,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Text(alert['type'] == 'success' ? 'Target Tercapai!' : 'Peringatan!'),
                ],
              ),
              content: Text(
                alert['message'], 
                style: const TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(); // Tutup dialog
                  },
                  child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            ),
          );
        }
      }
      // === AKHIR LOGIKA POP UP ===
        if (mounted) {
          // Kembali ke dashboard dan beri tahu bahwa ada data baru
          Navigator.of(context).popUntil(
            (route) => route.settings.name == '/dashboard' || route.isFirst
          );
          // Gunakan Navigator state untuk trigger refresh
          // Dashboard akan refresh otomatis karena menerima result
        }
      } else {
        // Gagal
        final body = json.decode(response.body);
        _showError(body['error'] ?? 'Gagal menyimpan data.');
      }
    } catch (e) {
      _showError('Gagal terhubung ke server. Cek koneksi & IP.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ambil data nutrisi dari argumen rute
    final Map<String, dynamic> nutritionData =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    // (Ini masih sama seperti file Anda sebelumnya)
    final String foodName =
        nutritionData['foodName'] ?? 'Makanan Tidak Dikenali';
    final int calories = (nutritionData['calories'] ?? 0).round();
    final int protein = (nutritionData['protein'] ?? 0).round();
    final int carbs = (nutritionData['carbs'] ?? 0).round();
    final int fat = (nutritionData['fat'] ?? 0).round();
    final String nutritionInfo =
        'Perkiraan: $calories Kkal, $protein g Protein, $carbs g Karbo, $fat g Lemak';
    final String? localPath = nutritionData['localImagePath']; // Ambil path lokal
    final String imageUrl =
        nutritionData['imageUrl'] ?? 'https://placehold.co/600x400?text=Error';
    // (Batas kode lama)

    return Scaffold(
      appBar: AppBar(title: const Text('Konfirmasi Makanan')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Container Gambar (Tidak Berubah)
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: (localPath != null)
                    ? Image.file( // Gunakan file dari device
                        File(localPath),
                        fit: BoxFit.cover,
                      )
                    : Image.network( // Fallback jika path tidak ada
                        imageUrl,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Teks Info Nutrisi (Tidak Berubah)
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
              nutritionInfo,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
            ),
            const Spacer(),

            // --- BAGIAN YANG BERUBAH ---
            // Tombol "Tambahkan ke Jurnal"
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: MyApp.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              // Nonaktifkan tombol saat loading
              onPressed: _isLoading ? null : () => _saveToJournal(nutritionData),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.0,
                      ),
                    )
                  : const Text(
                      'Ya, Tambahkan ke Jurnal',
                      style: TextStyle(fontSize: 16),
                    ),
            ),

            /*const SizedBox(height: 12),
            // Tombol "Bukan, Cari Manual"
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              // Nonaktifkan tombol saat loading
              onPressed: _isLoading
                  ? null
                  : () {
                      Navigator.pushReplacementNamed(context, '/search'); // Ganti ke /search
                    },
              child: const Text(
                'Bukan, Cari Manual',
                style: TextStyle(fontSize: 16),
              ),
            ),*/
          ],
        ),
      ),
    );
  }
}