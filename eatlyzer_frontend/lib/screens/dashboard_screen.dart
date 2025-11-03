// === lib/screens/dashboard_screen.dart ===

import 'package:flutter/material.dart';
import 'package:eatlyzer_frontend/main.dart'; // Import main.dart untuk akses warna
import 'package:eatlyzer_frontend/widgets/food_list_item.dart';
import 'package:eatlyzer_frontend/widgets/nutrition_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
              'Ringkasan Hari Ini',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              // TODO: Navigasi ke halaman profil
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Bagian Total Nutrisi (Horizontal)
            const Text(
              'Total Asupan Nutrisi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120, // tinggi untuk list horizontal
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: const [
                  NutritionCard(
                    label: 'Kalori',
                    value: '1250',
                    unit: 'kkal',
                    color: MyApp.lightBlueBg,
                  ),
                  SizedBox(width: 12),
                  NutritionCard(
                    label: 'Protein',
                    value: '80',
                    unit: 'g',
                    color: Color(0xFFE6F3E6), // Hijau muda
                  ),
                  SizedBox(width: 12),
                  NutritionCard(
                    label: 'Karbo',
                    value: '150',
                    unit: 'g',
                    color: Color(0xFFFFF3E0), // Oranye muda
                  ),
                  SizedBox(width: 12),
                  NutritionCard(
                    label: 'Lemak',
                    value: '40',
                    unit: 'g',
                    color: Color(0xFFFBE6E6), // Merah muda
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Bagian Jurnal Makanan (Vertikal)
            const Text(
              'Jurnal Makanan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            
            // Data Dummy
            const FoodListItem(
              foodName: 'Nasi Goreng Spesial',
              calories: '450 kkal',
              time: 'Sarapan',
              icon: Icons.rice_bowl,
            ),
            const FoodListItem(
              foodName: 'Apel',
              calories: '95 kkal',
              time: 'Camilan',
              icon: Icons.apple,
            ),
            const FoodListItem(
              foodName: 'Ayam Bakar Dada',
              calories: '320 kkal',
              time: 'Makan Siang',
              icon: Icons.restaurant,
            ),
          ],
        ),
      ),

      // Tombol Scan di tengah
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        shape: CircleBorder(),
        onPressed: () {
          Navigator.pushNamed(context, '/scan');
        },
        child: const Icon(Icons.camera_alt_outlined),
      ),

      // Bottom App Bar
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Container(
          height: 60.0,
          // Anda bisa menambahkan item menu lain di sini jika perlu
        ),
      ),
    );
  }
}