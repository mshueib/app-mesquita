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

  static Future<List<String>> carregarIdsNotificados() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('ids_avisos_notificados') ?? [];
  }

  static Future<void> salvarIdsNotificados(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('ids_avisos_notificados', ids);
  }

  static Future<List<String>> carregarFavoritos() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('mesquitas_favoritas') ?? [];
  }

  static Future<void> salvarFavoritos(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('mesquitas_favoritas', ids);
  }

  static Future<bool> notificacoesAtivas() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notificacoes_ativas') ?? true;
  }

  static Future<void> setNotificacoes(bool valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificacoes_ativas', valor);
  }

  static Future<bool> notificacoesHorariosAtivas() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notif_horarios') ?? true;
  }

  static Future<void> setNotificacoesHorarios(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_horarios', value);
  }

  static Future<bool> notificacoesAvisosAtivos() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notif_avisos') ?? true;
  }

  static Future<void> setNotificacoesAvisos(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_avisos', value);
  }

  static Future<bool> alarmeAzanAtivo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('alarme_azan') ?? true;
  }

  static Future<void> setAlarmeAzan(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alarme_azan', value);
  }
}
