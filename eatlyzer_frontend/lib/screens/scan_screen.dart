// === lib/screens/scan_screen.dart ===

import 'dart:convert'; // Untuk json.decode
import 'package:flutter/material.dart';
import 'package:eatlyzer_frontend/main.dart';
import 'package:eatlyzer_frontend/services/secure_storage_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  String _statusMessage = 'Mempersiapkan kamera...';
  
  // Inisialisasi storage service
  final SecureStorageService _storageService = SecureStorageService(); // <-- BARU

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
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() {
      _statusMessage = 'Menganalisis makanan Anda...';
    });

    try {
      // 2. Ambil base URL dan Token dari Secure Storage
      final String baseUrl = await _storageService.getBaseUrl();
      final String? token = await _storageService.readToken(); // <-- BARU

      // Cek jika token tidak ada (seharusnya tidak terjadi jika sudah login)
      if (token == null) {
        _showErrorAndPop('Token tidak ditemukan. Silakan login kembali.');
        // TODO: Navigasi paksa ke halaman login
        return;
      }

      // Tentukan URL endpoint
      final String _backendUrl = '$baseUrl/analyze'; // <-- BERUBAH

      // 3. Buat request Multipart
      var request = http.MultipartRequest('POST', Uri.parse(_backendUrl));

      // 4. TAMBAHKAN TOKEN KE HEADER
      request.headers['Authorization'] = 'Bearer $token'; // <-- BARU

      // 'image' harus sama dengan nama field di `upload.single('image')`
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      // 5. Kirim request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      // 6. Proses respon
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('error')) {
          _showErrorAndPop(data['error']);
        } else {
          // ===================================
          // Tambahkan path file lokal ke data
          data['localImagePath'] = image.path; 
          // ===================================

          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/confirm',
              arguments: data, // 'data' sekarang berisi path lokal
            );
          }
        }
      }else if (response.statusCode == 401) { // Penanganan error 401
         _showErrorAndPop('Sesi Anda habis. Silakan login kembali.');
         // TODO: Navigasi paksa ke halaman login
      } else {
        _showErrorAndPop('Error server: ${response.statusCode}');
      }
    } catch (e) {
      // Error koneksi
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
    // UI loading (tidak berubah)
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
