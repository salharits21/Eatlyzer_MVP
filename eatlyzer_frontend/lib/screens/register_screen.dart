// === lib/screens/register_screen.dart ===
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:eatlyzer_frontend/main.dart';
import 'package:eatlyzer_frontend/services/secure_storage_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // --- TAMBAHAN BARU ---
  final _confirmPasswordController = TextEditingController(); 
  // ---------------------

  final _storageService = SecureStorageService();
  bool _isLoading = false;

  Future<void> _register() async {
    // Validasi form (sekarang juga akan mengecek konfirmasi password)
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; });

    try {
      final baseUrl = await _storageService.getBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': _nameController.text,
          'email': _emailController.text,
          'password': _passwordController.text, // Kita hanya kirim password utama
        }),
      );

      final body = json.decode(response.body);

      if (response.statusCode == 201) {
        await _storageService.saveToken(body['token']);
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        _showError(body['error'] ?? 'Gagal mendaftar');
      }
    } catch (e) {
      _showError('Tidak dapat terhubung ke server. Periksa IP/Koneksi.');
    } finally {
      setState(() { _isLoading = false; });
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 48),
                const Text(
                  'Buat Akun Baru',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Mulai perjalanan nutrisi Anda',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 48),

                // Nama
                TextFormField(
                  controller: _nameController,
                  decoration: _buildInputDecoration('Nama Lengkap', Icons.person_outline),
                  keyboardType: TextInputType.name,
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Nama tidak boleh kosong' : null,
                ),
                const SizedBox(height: 16),
                
                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: _buildInputDecoration('Email', Icons.email_outlined),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => (value == null || !value.contains('@'))
                      ? 'Masukkan email yang valid' : null,
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  decoration: _buildInputDecoration('Password', Icons.lock_outline),
                  obscureText: true,
                  validator: (value) => (value == null || value.length < 6)
                      ? 'Password minimal 6 karakter' : null,
                ),
                const SizedBox(height: 16), // Tambah jarak

                // --- TAMBAHAN BARU: KONFIRMASI PASSWORD ---
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: _buildInputDecoration('Konfirmasi Password', Icons.lock_outline),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Mohon konfirmasi password Anda';
                    }
                    if (value != _passwordController.text) {
                      return 'Password tidak cocok';
                    }
                    return null;
                  },
                ),
                // -------------------------------------
                
                const SizedBox(height: 32),

                // Tombol Register
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        style: _buildButtonStyle(),
                        onPressed: _register, // Fungsi _register tidak perlu diubah
                        child: Text(
                            'Daftar',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold
                            ),
                          ),
                      ),
                
                // Link ke Login
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: RichText(
                    text: TextSpan(
                      text: 'Sudah punya akun? ',
                      style: GoogleFonts.poppins(color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'Login di sini',
                          style: GoogleFonts.poppins(
                            color: MyApp.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  ButtonStyle _buildButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: MyApp.primaryColor,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: MyApp.primaryColor),
      ),
    );
  }
}