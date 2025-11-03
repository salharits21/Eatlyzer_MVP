// === lib/main.dart ===

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eatlyzer_frontend/screens/confirmation_screen.dart';
import 'package:eatlyzer_frontend/screens/dashboard_screen.dart';
import 'package:eatlyzer_frontend/screens/manual_search_screen.dart';
import 'package:eatlyzer_frontend/screens/scan_screen.dart';

// Ganti 'nama_proyek_anda' dengan nama proyek Anda

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Warna utama kita
  static const Color primaryColor = Color(0xFF00B0FF); // Sky Blue
  static const Color lightBlueBg = Color(0xFFE3F8FF); // Latar belakang biru sangat muda

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriScan MVP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Font modern
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        
        // Latar belakang utama
        scaffoldBackgroundColor: Colors.white,

        // Tema AppBar (minimalis)
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black),
          titleTextStyle: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),

        // Tema Floating Action Button
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const DashboardScreen(),
        '/scan': (context) => const ScanScreen(),
        '/confirm': (context) => const ConfirmationScreen(),
        '/search': (context) => const ManualSearchScreen(),
      },
    );
  }
}