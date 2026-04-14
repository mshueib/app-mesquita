import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifHorarios = true;
  bool _notifAvisos = true;
  bool _alarmeAzan = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() async {
    final h = await LocalStorageService.notificacoesHorariosAtivas();
    final a = await LocalStorageService.notificacoesAvisosAtivos();
    final z = await LocalStorageService.alarmeAzanAtivo();
    setState(() {
      _notifHorarios = h;
      _notifAvisos = a;
      _alarmeAzan = z;
    });
  }

  void _toggleHorarios(bool value) async {
    setState(() => _notifHorarios = value);
    await LocalStorageService.setNotificacoesHorarios(value);
  }

  void _toggleAvisos(bool value) async {
    setState(() => _notifAvisos = value);
    await LocalStorageService.setNotificacoesAvisos(value);
  }

  void _toggleAzan(bool value) async {
    setState(() => _alarmeAzan = value);
    await LocalStorageService.setAlarmeAzan(value);
    if (!value) {
      await NotificationService.cancelarAzan();
    }
  }

  Widget _tile(String titulo, String subtitulo, IconData icone, bool value,
      Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF0B3D2E).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icone, color: const Color(0xFF0B3D2E), size: 20),
        ),
        title: Text(titulo,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitulo,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF0B3D2E),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EA),
      appBar: AppBar(
        title: const Text("Notificações"),
        backgroundColor: const Color(0xFF0B3D2E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text("Preferências",
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey)),
          ),
          _tile(
              "Horários de Salat",
              "Notificação quando o admin actualiza horários",
              Icons.access_time,
              _notifHorarios,
              _toggleHorarios),
          _tile("Avisos", "Janazah, Nikah e avisos gerais",
              Icons.campaign_outlined, _notifAvisos, _toggleAvisos),
          _tile("Alarme de Azan/Iqamah", "Alarme diário nas horas de oração",
              Icons.notifications_active_outlined, _alarmeAzan, _toggleAzan),
        ],
      ),
    );
  }
}
