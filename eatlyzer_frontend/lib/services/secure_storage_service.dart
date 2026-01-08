// === lib/services/secure_storage_service.dart ===
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _ipKey = 'backend_ip'; // <-- Tambahan untuk menyimpan IP

  // --- Token ---
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> readToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // --- IP Address ---
  // (Ini helper agar user bisa ganti IP backend jika perlu)
  Future<void> saveIP(String ip) async {
    await _storage.write(key: _ipKey, value: ip);
  }

  Future<String?> readIP() async {
    return await _storage.read(key: _ipKey);
  }
  
  // Helper untuk base URL
  Future<String> getBaseUrl() async {
    // !! Ganti IP default ini dengan IP Anda
<<<<<<< HEAD
    final String defaultIP = '192.168.56.1'; 
=======
    final String defaultIP = '10.0.2.2'; 
>>>>>>> b56263eeef72ef8fbe987aedf0db23ef082a9621
    final String? storedIP = await readIP();
    return 'http://${storedIP ?? defaultIP}:3000';
  }
}