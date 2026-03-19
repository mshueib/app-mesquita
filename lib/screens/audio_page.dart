import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _modo = "LIVE"; // LIVE ou GRAVAÇÕES

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(
          Uri.parse("https://media.smartbilal.com/masjid/mzcentraldequelimane"))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
      );
  }

  void _abrirLive() {
    setState(() {
      _modo = "LIVE";
      _isLoading = true;
    });

    _controller.loadRequest(
        Uri.parse("https://media.smartbilal.com/masjid/mzcentraldequelimane"));
  }

  void _abrirGravacoes() {
    setState(() {
      _modo = "GRAVAÇÕES";
      _isLoading = true;
    });

    _controller.loadRequest(Uri.parse(
        "https://media.smartbilal.com/masjid/mzcentraldequelimane/recordings"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EA),
      appBar: AppBar(
        title: const Text("Áudio"),
        backgroundColor: const Color(0xFF0B3D2E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // 🔴 BANNER SUPERIOR
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF0B3D2E),
            child: Text(
              _modo == "LIVE"
                  ? "🔴 Transmissão ao Vivo"
                  : "🎧 Gravações da Mesquita",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // 🔘 BOTÕES
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _abrirLive,
                  icon: const Icon(Icons.radio),
                  label: const Text("Live"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _modo == "LIVE" ? Colors.red : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _abrirGravacoes,
                  icon: const Icon(Icons.library_music),
                  label: const Text("Gravações"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _modo == "GRAVAÇÕES"
                        ? const Color(0xFF0B3D2E)
                        : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // 🌐 WEBVIEW + LOADER
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  Container(
                    color: Colors.black12,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
