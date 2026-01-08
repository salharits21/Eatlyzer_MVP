// === lib/screens/splash_screen.dart ===
import 'package:eatlyzer_frontend/main.dart';
import 'package:flutter/material.dart';
import 'package:eatlyzer_frontend/services/secure_storage_service.dart'; // Ganti

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final SecureStorageService _storageService = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Beri jeda sedikit agar logo terlihat (opsional)
    await Future.delayed(const Duration(milliseconds: 1500)); 

    final token = await _storageService.readToken();
    
    if (mounted) {
      if (token != null) {
        // Ada token, lempar ke Dashboard
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        // Tidak ada token, lempar ke Login
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ganti dengan logo Anda nanti
            Icon(Icons.food_bank_rounded, size: 100, color: MyApp.primaryColor),
            SizedBox(height: 20),
            Text(
              'EatLyzer',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: MyApp.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}