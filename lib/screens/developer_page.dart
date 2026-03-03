import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class DeveloperPage extends StatefulWidget {
  const DeveloperPage({super.key});

  @override
  State<DeveloperPage> createState() => _DeveloperPageState();
}

class _DeveloperPageState extends State<DeveloperPage> {
  String _version = "";

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = "${info.version} (${info.buildNumber})";
    });
  }

  Future<void> _abrirEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'muhamad.shueib@gmail.com',
      query: 'subject=Mosque Now - Contacto',
    );

    await launchUrl(emailUri);
  }

  Future<void> _abrirPolitica() async {
    final Uri url =
        Uri.parse('https://sites.google.com/view/mosque-now-privacy');

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          children: [
            // 🔥 ÍCONE REAL DO APP
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/icon.png',
                height: 110,
                width: 110,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Mosque Now",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B3D2E),
              ),
            ),

            const SizedBox(height: 6),

            Text(
              "Versão $_version",
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 20),

            // 🔐 POLÍTICA
            const Text(
              "Política de Segurança",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B3D2E),
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              "Este aplicativo não recolhe dados pessoais sensíveis.\n"
              "As informações utilizadas destinam-se apenas ao funcionamento\n"
              "interno como notificações e horários de oração.\n\n"
              "Nenhum dado é partilhado com terceiros.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _abrirPolitica,
              icon: const Icon(Icons.privacy_tip),
              label: const Text("Política de Privacidade"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 166, 248, 223),
              ),
            ),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 20),

            // 📩 CONTACTO
            const Text(
              "Contactar Desenvolvedor",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B3D2E),
              ),
            ),

            const SizedBox(height: 15),

            ElevatedButton.icon(
              onPressed: _abrirEmail,
              icon: const Icon(Icons.email),
              label: const Text("Enviar Email"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: const Color(0xFF0B3D2E),
              ),
            ),

            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 20),

            // 👤 DESENVOLVIDO POR (AGORA NO FIM)
            const Text(
              "Desenvolvido por",
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 6),

            const Text(
              "MSY",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text("📍 Quelimane, Moçambique"),

            const SizedBox(height: 20),

            const Text(
              "© 2026 Mosque Now\nTodos os direitos reservados.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
