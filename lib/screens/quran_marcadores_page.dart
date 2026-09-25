import 'package:flutter/material.dart';
import '../services/quran_service.dart';
import 'quran_page.dart';

class QuranMarcadoresPage extends StatefulWidget {
  const QuranMarcadoresPage({super.key});

  @override
  State<QuranMarcadoresPage> createState() => _QuranMarcadoresPageState();
}

class _QuranMarcadoresPageState extends State<QuranMarcadoresPage> {
  late Future<List<QuranMarcador>> _futureMarcadores;

  @override
  void initState() {
    super.initState();
    _futureMarcadores = QuranService.listarMarcadores();
  }

  void _recarregar() {
    setState(() {
      _futureMarcadores = QuranService.listarMarcadores();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3D2E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Marcadores", style: TextStyle(color: Colors.white)),
      ),
      body: FutureBuilder<List<QuranMarcador>>(
        future: _futureMarcadores,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0B3D2E)),
            );
          }

          final marcadores = snapshot.data ?? [];

          if (marcadores.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  "Ainda não tens marcadores.\nDurante a leitura, toca no ícone de marcador no topo para guardar a página aqui.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: marcadores.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final m = marcadores[index];
              return Dismissible(
                key: ValueKey(m.criadoEm.toIso8601String()),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) async {
                  await QuranService.removerMarcador(m.criadoEm);
                  _recarregar();
                },
                child: ListTile(
                  leading: const Icon(Icons.bookmark, color: Color(0xFFD4AF37)),
                  title: Text(
                    m.nome,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("Juz ${m.juz} — página ${m.pagina}"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            JuzReaderPage(juz: m.juz, paginaInicial: m.pagina),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
