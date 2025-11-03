// === lib/screens/scan_screen.dart ===

import 'package:eatlyzer_frontend/main.dart';
import 'package:flutter/material.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  @override
  void initState() {
    super.initState();
    // Simulasi proses scan selama 2 detik
    Future.delayed(const Duration(seconds: 2), () {
      // Setelah 2 detik, pindah ke layar konfirmasi
      // Kita "mengirim" hasil tebakan AI sebagai argumen
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/confirm',
          arguments: 'Nasi Goreng', // Ini hasil tebakan palsu dari AI
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyApp.primaryColor, // Latar belakang biru
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 20),
            Text(
              'Menganalisis makanan Anda...',
              style: TextStyle(
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