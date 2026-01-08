import 'dart:convert';
import 'package:eatlyzer_frontend/services/secure_storage_service.dart';
import 'package:eatlyzer_frontend/main.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class GoalSettingScreen extends StatefulWidget {
  const GoalSettingScreen({super.key});

  @override
  State<GoalSettingScreen> createState() => _GoalSettingScreenState();
}

class _GoalSettingScreenState extends State<GoalSettingScreen> {
  final SecureStorageService _storageService = SecureStorageService();
  final _formKey = GlobalKey<FormState>();

  String _goalType = 'limit'; // 'limit' (Cutting) or 'target' (Bulking)
  final TextEditingController _calController = TextEditingController();
  final TextEditingController _proController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentGoals();
  }

  Future<void> _fetchCurrentGoals() async {
    // Ambil data target yang sudah ada (jika ada)
    final baseUrl = await _storageService.getBaseUrl();
    final token = await _storageService.readToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/goals'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 && response.body != 'null') {
        final data = json.decode(response.body);
        setState(() {
          _goalType = data['goal_type'] ?? 'limit';
          _calController.text = data['calories_goal'].toString();
          _proController.text = data['protein_goal'].toString();
          _carbsController.text = data['carbs_goal'].toString();
          _fatController.text = data['fat_goal'].toString();
        });
      }
    } catch (e) {
      // Abaikan error fetch, biarkan kosong
    }
  }

  Future<void> _saveGoals() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final baseUrl = await _storageService.getBaseUrl();
      final token = await _storageService.readToken();
      
      final body = {
        'goalType': _goalType,
        'calories': int.parse(_calController.text),
        'protein': int.parse(_proController.text),
        'carbs': int.parse(_carbsController.text),
        'fat': int.parse(_fatController.text),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/user/goals'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Target berhasil disimpan!')),
          );
          Navigator.pop(context, true); // Kembali dan refresh dashboard
        }
      } else {
        throw Exception('Gagal menyimpan');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terjadi kesalahan koneksi.')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Atur Target Nutrisi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih Mode Program',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _goalType,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                    value: 'limit',
                    child: Text('Cutting / Diet (Batas Maksimal)'),
                  ),
                  DropdownMenuItem(
                    value: 'target',
                    child: Text('Bulking (Target Minimal)'),
                  ),
                ],
                onChanged: (val) => setState(() => _goalType = val!),
              ),
              const SizedBox(height: 12),
              // Helper text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _goalType == 'limit' ? Colors.orange[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300)
                ),
                child: Row(
                  children: [
                    Icon(_goalType == 'limit' ? Icons.warning_amber : Icons.flag, 
                         color: _goalType == 'limit' ? Colors.orange : Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _goalType == 'limit' 
                          ? 'Anda akan diperingatkan jika makan MELEBIHI angka di bawah.'
                          : 'Anda akan diberi selamat jika makan MENCAPAI angka di bawah.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              _buildNumInput('Target Kalori (kkal)', _calController),
              _buildNumInput('Target Protein (g)', _proController),
              _buildNumInput('Target Karbohidrat (g)', _carbsController),
              _buildNumInput('Target Lemak (g)', _fatController),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyApp.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isLoading ? null : _saveGoals,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('Simpan Pengaturan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumInput(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
      ),
    );
  }
}