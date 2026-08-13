import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../services/audio_service.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  late final WebViewController _controller;
  bool _isLoadingWebview = false;
  String _modo = "GRAVAÇÕES"; // começa mais leve

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSub;

  List<Recording> _gravacoes = [];
  bool _carregandoLista = true;
  bool _carregandoMais = false;
  String? _erroLista;
  String? _nextPageUrl;
  final Set<String> _baixados = {};
  final Map<String, double> _progressoDownload = {};
  String? _urlTocando;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isLoadingWebview = true);
          },
          onPageFinished: (url) async {
            setState(() => _isLoadingWebview = false);

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

    _playerStateSub = _player.playerStateStream.listen((_) {
      if (mounted) setState(() {});
    });

    _carregarGravacoesIniciais();
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _abrirLive() {
    setState(() {
      _modo = "LIVE";
      _isLoadingWebview = true;
    });

    _controller.loadRequest(
        Uri.parse("https://media.smartbilal.com/masjid/mzcentraldequelimane"));
  }

  void _abrirGravacoes() {
    setState(() => _modo = "GRAVAÇÕES");

    if (_gravacoes.isEmpty && !_carregandoLista) {
      _carregarGravacoesIniciais();
    }
  }

  Future<void> _carregarGravacoesIniciais() async {
    setState(() {
      _carregandoLista = true;
      _erroLista = null;
    });

    try {
      final pagina = await AudioService.fetchRecordings();
      final baixados = await _filtrarBaixados(pagina.items);

      if (!mounted) return;
      setState(() {
        _gravacoes = pagina.items;
        _nextPageUrl = pagina.nextPageUrl;
        _baixados
          ..clear()
          ..addAll(baixados);
        _carregandoLista = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erroLista = "Não foi possível carregar as gravações.";
        _carregandoLista = false;
      });
    }
  }

  Future<void> _carregarMais() async {
    if (_nextPageUrl == null || _carregandoMais) return;

    setState(() => _carregandoMais = true);

    try {
      final pagina = await AudioService.fetchRecordings(pageUrl: _nextPageUrl);
      final baixados = await _filtrarBaixados(pagina.items);

      if (!mounted) return;
      setState(() {
        _gravacoes.addAll(pagina.items);
        _nextPageUrl = pagina.nextPageUrl;
        _baixados.addAll(baixados);
        _carregandoMais = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregandoMais = false);
    }
  }

  Future<List<String>> _filtrarBaixados(List<Recording> itens) async {
    final resultado = <String>[];
    for (final r in itens) {
      if (await AudioService.isDownloaded(r.url)) resultado.add(r.url);
    }
    return resultado;
  }

  Future<void> _tocarOuPausar(Recording r) async {
    if (_urlTocando == r.url) {
      _player.playing ? await _player.pause() : await _player.play();
      return;
    }

    setState(() => _urlTocando = r.url);

    try {
      if (_baixados.contains(r.url)) {
        final file = await AudioService.localFile(r.url);
        await _player.setFilePath(file.path);
      } else {
        await _player.setUrl(r.url);
      }
      await _player.play();
    } catch (e) {
      if (!mounted) return;
      setState(() => _urlTocando = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Não foi possível reproduzir este áudio.")),
      );
    }
  }

  Future<void> _baixar(Recording r) async {
    setState(() => _progressoDownload[r.url] = 0);

    try {
      await AudioService.download(
        r.url,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _progressoDownload[r.url] = p);
        },
      );

      if (!mounted) return;
      setState(() {
        _progressoDownload.remove(r.url);
        _baixados.add(r.url);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _progressoDownload.remove(r.url));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Falha ao baixar o áudio.")),
      );
    }
  }

  Future<void> _removerDownload(Recording r) async {
    await AudioService.deleteDownload(r.url);
    if (!mounted) return;
    setState(() => _baixados.remove(r.url));
  }

  String _formatarTitulo(Recording r) {
    if (r.startAt == null) return r.title;
    return DateFormat('dd/MM/yyyy HH:mm').format(r.startAt!.toLocal());
  }

  Future<void> _partilhar(Recording r) async {
    final file = await AudioService.localFile(r.url);
    if (!await file.exists()) return;

    await Share.shareXFiles(
      [XFile(file.path)],
      text: "Gravação Masjid Central: Quelimane — ${_formatarTitulo(r)}",
    );
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
                  : "🎧 Gravações do Masjid",
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

          Expanded(
            child: _modo == "LIVE" ? _buildLive() : _buildGravacoes(),
          ),
        ],
      ),
    );
  }

  Widget _buildLive() {
    return Stack(
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
        if (_isLoadingWebview)
          Container(
            color: Colors.white.withOpacity(0.7),
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0B3D2E),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGravacoes() {
    if (_carregandoLista) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0B3D2E)),
      );
    }

    if (_erroLista != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_erroLista!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _carregarGravacoesIniciais,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B3D2E),
                  foregroundColor: Colors.white,
                ),
                child: const Text("Tentar novamente"),
              ),
            ],
          ),
        ),
      );
    }

    if (_gravacoes.isEmpty) {
      return const Center(child: Text("Sem gravações disponíveis"));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _gravacoes.length + (_nextPageUrl != null ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == _gravacoes.length) {
          return Center(
            child: _carregandoMais
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(color: Color(0xFF0B3D2E)),
                  )
                : TextButton(
                    onPressed: _carregarMais,
                    child: const Text("Carregar mais"),
                  ),
          );
        }

        return _itemGravacao(_gravacoes[index]);
      },
    );
  }

  Widget _itemGravacao(Recording r) {
    final tocandoEste = _urlTocando == r.url && _player.playing;
    final baixado = _baixados.contains(r.url);
    final progresso = _progressoDownload[r.url];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF0B3D2E),
          child: IconButton(
            icon: Icon(
              tocandoEste ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: () => _tocarOuPausar(r),
          ),
        ),
        title: Text(
          _formatarTitulo(r),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          "${r.durationMin} min${baixado ? ' • guardado no dispositivo' : ''}",
        ),
        trailing: progresso != null
            ? SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  value: progresso,
                  strokeWidth: 3,
                  color: const Color(0xFF0B3D2E),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (baixado)
                    IconButton(
                      icon: const Icon(Icons.share_outlined,
                          color: Color(0xFF0B3D2E)),
                      onPressed: () => _partilhar(r),
                    ),
                  IconButton(
                    icon: Icon(
                      baixado ? Icons.delete_outline : Icons.download,
                      color: baixado ? Colors.red : const Color(0xFF0B3D2E),
                    ),
                    onPressed: () => baixado ? _removerDownload(r) : _baixar(r),
                  ),
                ],
              ),
      ),
    );
  }
}
