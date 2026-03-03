import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LocalStorageService {
  static const String _key = "dados_cache";

  static Future<void> salvarDados(Map<String, dynamic> dados) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(dados));
  }

  static Future<Map<String, dynamic>?> carregarDados() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);

    if (jsonString == null) return null;

    return jsonDecode(jsonString);
  }
}
