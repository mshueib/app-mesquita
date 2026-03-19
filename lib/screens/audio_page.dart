import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _modo = "GRAVAÇÕES"; // começa mais leve

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(false)
      ..loadRequest(Uri.parse(
          "https://media.smartbilal.com/masjid/mzcentraldequelimane/recordings"))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (url) async {
            setState(() => _isLoading = false);

            await _controller.runJavaScript('''
    document.documentElement.style.overflowX = 'hidden';
    document.body.style.overflowX = 'hidden';
    document.body.style.width = '100vw';
    document.body.style.maxWidth = '100vw';
    document.body.style.touchAction = 'pan-y';

    document.querySelectorAll("*").forEach(e => {
      e.style.maxWidth = '100vw';
      e.style.boxSizing = 'border-box';
    });

    document.querySelectorAll("img").forEach(e => e.style.display="none");
    document.querySelectorAll("header").forEach(e => e.style.display="none");
    document.querySelectorAll("footer").forEach(e => e.style.display="none");
  ''');
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
        backgroundColor: const Color.fromARGB(255, 217, 232, 227),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // 🔴 BANNER
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

          // 🌐 WEBVIEW
          Expanded(
            child: Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) {},
                  onHorizontalDragUpdate: (_) {},
                  onHorizontalDragEnd: (_) {},
                  child: WebViewWidget(
                    controller: _controller,
                    gestureRecognizers: {
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                  ),
                ),
                if (_isLoading)
                  Container(
                    color: Colors.white.withOpacity(0.7),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0B3D2E),
                      ),
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
