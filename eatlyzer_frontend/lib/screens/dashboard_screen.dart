// === lib/screens/dashboard_screen.dart ===

import 'dart:convert';

import 'package:eatlyzer_frontend/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:eatlyzer_frontend/main.dart'; // Import main.dart untuk akses warna
import 'package:eatlyzer_frontend/widgets/food_list_item.dart';
import 'package:eatlyzer_frontend/widgets/nutrition_card.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // Untuk format waktu

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SecureStorageService _storageService = SecureStorageService();

  // Variabel untuk menyimpan state
  bool _isLoading = true;
  String? _errorMessage;
  String _userName = 'Pengguna';
  String _userEmail = '';
  Map<String, dynamic> _summary = {
    'total_calories': 0,
    'total_protein': 0,
    'total_carbs': 0,
    'total_fat': 0,
  };
  List<dynamic> _entries = [];

  @override
  void initState() {
    super.initState();
    // Panggil API saat layar pertama kali dibuka
    _fetchDashboardData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data setiap kali dashboard muncul kembali
    if (ModalRoute.of(context)?.isCurrent == true) {
      _fetchDashboardData();
    }
  }

  // Fungsi untuk mengambil data dari backend
  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final baseUrl = await _storageService.getBaseUrl();
      final token = await _storageService.readToken();

      if (token == null) {
        _handleLogout(); // Jika token tidak ada, paksa logout
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/journal/today'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Sukses
        final data = json.decode(response.body);
        setState(() {
          _userName = data['user']['name'] ?? 'Pengguna';
          _userEmail = data['user']['email'] ?? '';
          _summary = data['summary'];
          _entries = data['entries'];
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        // Token tidak valid/kadaluarsa
        _handleLogout();
      } else {
        // Error server lain
        setState(() {
          _errorMessage = 'Gagal memuat data.';
          _isLoading = false;
        });
      }
    } catch (e) {
      // Error koneksi
      setState(() {
        _errorMessage = 'Gagal terhubung ke server.';
        _isLoading = false;
      });
    }
  }

  // Fungsi untuk logout
  Future<void> _handleLogout() async {
    await _storageService.deleteToken();
    if (mounted) {
      // Pindah ke login dan hapus semua layar sebelumnya
      Navigator.pushNamedAndRemoveUntil(
          context, '/login', (route) => false);
    }
  }

  // Helper untuk format waktu di list
  String _formatTime(String isoTimestamp) {
    try {
      final dateTime = DateTime.parse(isoTimestamp).toLocal();
      return DateFormat.Hm().format(dateTime); // Format "HH:mm" (misal: 14:30)
    } catch (e) {
      return '';
    }
  }

  // --- UI (Build Method) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, $_userName!'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.person_outline), 
            offset: const Offset(0, 56), 
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              // Tambahkan border tipis agar terlihat di atas background putih
              side: BorderSide(color: Colors.grey[200]!) 
            ),
            color: Colors.white, // <-- SET LATAR BELAKANG POPUP
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              // Menu Item: Profile Info (Header)
              PopupMenuItem<String>(
                enabled: false,
                padding: EdgeInsets.zero,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  // Kita tidak perlu warna lagi di sini, karena 'color' di atas
                  // sudah mengatur seluruh popup.
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: MyApp.primaryColor,
                        child: Icon(Icons.person, size: 36, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _userName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black), // Pastikan warna teks
                      ),
                      const SizedBox(height: 4),
                      
                      // !! TAMBAHAN EMAIL DI SINI !!
                      Text(
                        _userEmail,
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(), 

              // Menu Item: Logout
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: const [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Logout',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (String value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
          ),
        ],
      ),
      body: _buildBody(), // Pindahkan body ke fungsi terpisah
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        shape: CircleBorder(), 
        onPressed: () async {
          // Pindah ke layar scan, dan "refresh" data saat kembali
          await Navigator.pushNamed(context, '/scan');
          // Jika scan berhasil (atau bahkan dibatalkan), refresh data dashboard
          
          //_fetchDashboardData();
          
        },
        child: const Icon(Icons.camera_alt_outlined),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Container(height: 60.0),
      ),
    );
  }

  // Widget untuk body (Loading, Error, atau Data)
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _fetchDashboardData,
              child: const Text('Coba Lagi'),
            )
          ],
        ),
      );
    }

    // Jika data berhasil dimuat
    return RefreshIndicator(
      onRefresh: _fetchDashboardData, // Tambahkan "Pull to Refresh"
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(), // Agar refresh selalu aktif
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Bagian Total Nutrisi (Data Dinamis)
            const Text(
              'Total Asupan Nutrisi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  NutritionCard(
                    label: 'Kalori',
                    value: (_summary['total_calories'] ?? 0).toString(),
                    unit: 'kkal',
                    color: MyApp.lightBlueBg,
                  ),
                  const SizedBox(width: 12),
                  NutritionCard(
                    label: 'Protein',
                    value: (_summary['total_protein'] ?? 0).toString(),
                    unit: 'g',
                    color: const Color(0xFFE6F3E6),
                  ),
                  const SizedBox(width: 12),
                  NutritionCard(
                    label: 'Karbo',
                    value: (_summary['total_carbs'] ?? 0).toString(),
                    unit: 'g',
                    color: const Color(0xFFFFF3E0),
                  ),
                  const SizedBox(width: 12),
                  NutritionCard(
                    label: 'Lemak',
                    value: (_summary['total_fat'] ?? 0).toString(),
                    unit: 'g',
                    color: const Color(0xFFFBE6E6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Bagian Jurnal Makanan (Data Dinamis)
            const Text(
              'Jurnal Makanan Hari Ini',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            
            _buildEntriesList(), // Panggil list dinamis
          ],
        ),
      ),
    );
  }

  // Widget untuk menampilkan list jurnal atau pesan "kosong"
  Widget _buildEntriesList() {
    if (_entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.fastfood_outlined, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Belum ada makanan hari ini',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const Text(
                'Coba scan makanan pertama Anda!',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Tampilkan list jika ada data
    return ListView.builder(
      itemCount: _entries.length,
      shrinkWrap: true, // Agar bisa di dalam SingleChildScrollView
      physics: const NeverScrollableScrollPhysics(), // Agar scroll utama yg bekerja
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return FoodListItem(
          foodName: entry['food_name'] ?? 'N/A',
          calories: '${entry['calories'] ?? 0} kkal',
          time: _formatTime(entry['created_at']), // Format waktu
          icon: Icons.restaurant, // Ikon default
        );
      },
    );
  }
}