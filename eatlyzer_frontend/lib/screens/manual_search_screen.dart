// === lib/screens/manual_search_screen.dart ===

import 'package:flutter/material.dart';

class ManualSearchScreen extends StatelessWidget {
  const ManualSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Kotak pencarian langsung di AppBar
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: const TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Cari makanan...',
              prefixIcon: Icon(Icons.search, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            ),
          ),
        ),
      ),
      body: ListView(
        // Ini adalah daftar hasil pencarian palsu
        children: [
          ListTile(
            title: const Text('Nasi Padang (Rendang)'),
            subtitle: const Text('Sekitar 650 kkal'),
            onTap: () {
              // TODO: Simpan 'Nasi Padang' ke database
              Navigator.popUntil(context, ModalRoute.withName('/'));
            },
          ),
          ListTile(
            title: const Text('Sate Ayam (10 tusuk)'),
            subtitle: const Text('Sekitar 350 kkal'),
            onTap: () {
              // TODO: Simpan 'Sate Ayam' ke database
              Navigator.popUntil(context, ModalRoute.withName('/'));
            },
          ),
          ListTile(
            title: const Text('Gado-gado'),
            subtitle: const Text('Sekitar 400 kkal'),
            onTap: () {
              // TODO: Simpan 'Gado-gado' ke database
              Navigator.popUntil(context, ModalRoute.withName('/'));
            },
          ),
        ],
      ),
    );
  }
}