import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificacoes = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() async {
    final ativo = await LocalStorageService.notificacoesAtivas();
    setState(() => _notificacoes = ativo);
  }

  void _toggle(bool value) async {
    setState(() => _notificacoes = value);

    await LocalStorageService.setNotificacoes(value);

    if (!value) {
      await NotificationService.cancelAll(); // 🔥 desativa tudo
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configurações"),
        backgroundColor: const Color.fromARGB(255, 236, 240, 239),
      ),
      body: ListTile(
        title: const Text("Receber notificações"),
        trailing: Switch(
          value: _notificacoes,
          onChanged: _toggle,
        ),
      ),
    );
  }
}
