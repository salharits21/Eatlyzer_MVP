// === lib/screens/scan_screen.dart ===

import 'dart:convert'; // Untuk json.decode
import 'package:flutter/material.dart';
import 'package:eatlyzer_frontend/main.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  String _statusMessage = 'Mempersiapkan kamera...';

  // !! PENTING: Ganti dengan IP Address lokal komputer Anda
  // !! Alamat IP ini diambil dari screenshot ipconfig Anda
  final String _backendUrl = 'http://192.168.0.123:3000/analyze';

  @override
  void initState() {
    super.initState();
    // Langsung panggil fungsi ambil & analisis gambar
    _pickAndAnalyzeImage();
  }

  Future<void> _pickAndAnalyzeImage() async {
    final ImagePicker picker = ImagePicker();

    // 1. Ambil gambar dari kamera
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image == null) {
      // User membatalkan pengambilan gambar, kembali ke dashboard
      if (mounted) Navigator.pop(context);
      return;
    }

    // 2. Tampilkan status "Menganalisis"
    setState(() {
      _statusMessage = 'Menganalisis makanan Anda...';
    });

    try {
      // 3. Buat request Multipart untuk upload gambar
      var request = http.MultipartRequest('POST', Uri.parse(_backendUrl));

      // 'image' harus sama dengan nama field di `upload.single('image')` pada Node.js
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      // 4. Kirim request dan tunggu respon
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      // 5. Proses respon
      if (response.statusCode == 200) {
        // Sukses! Data JSON diterima dari backend
        final Map<String, dynamic> data = json.decode(response.body);

        if (data.containsKey('error')) {
          // AI mengembalikan error (misal: bukan makanan)
          _showErrorAndPop(data['error']);
        } else {
          // Sukses, kirim data nutrisi ke halaman berikutnya
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/confirm',
              arguments: data, // Mengirim seluruh Map data nutrisi
            );
          }
        }
      } else {
        // Error dari server (500, 404, dll)
        _showErrorAndPop('Error server: ${response.statusCode}');
      }
    } catch (e) {
      // Error koneksi (timeout, IP salah, server mati)
      _showErrorAndPop('Gagal terhubung ke server. Cek koneksi & IP.');
    }
  }

  // Helper untuk menampilkan error dan kembali
  void _showErrorAndPop(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
      Navigator.pop(context); // Kembali ke dashboard
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ini adalah UI loading selama proses upload dan analisis
    return Scaffold(
      backgroundColor: MyApp.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
