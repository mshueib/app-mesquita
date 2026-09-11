import 'package:flutter/material.dart';
import '../services/hadith_service.dart';

/// Lista de colecções de Hadith (Bukhari, Muslim) — vive dentro do
/// PageView principal (sem AppBar própria).
class HadithPage extends StatelessWidget {
  const HadithPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F1EA),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: HadithService.colecoes.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Card(
              elevation: 1,
              color: const Color(0xFFFFF8E1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFD4AF37)),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFD4AF37),
                  child: Icon(Icons.star, color: Color(0xFF0B3D2E)),
                ),
                title: const Text(
                  "Hadiths Mais Conhecidos",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("Em português e inglês"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HadithsConhecidosPage(),
                  ),
                ),
              ),
            );
          }

          final colecao = HadithService.colecoes[index - 1];
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF0B3D2E),
                child: Icon(Icons.menu_book, color: Colors.white),
              ),
              title: Text(
                colecao.nome,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text("${colecao.secoes.length} capítulos"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HadithSecoesPage(colecao: colecao),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class HadithsConhecidosPage extends StatefulWidget {
  const HadithsConhecidosPage({super.key});

  @override
  State<HadithsConhecidosPage> createState() => _HadithsConhecidosPageState();
}

class _HadithsConhecidosPageState extends State<HadithsConhecidosPage> {
  late Future<List<HadithConhecido>> _future;

  @override
  void initState() {
    super.initState();
    _future = HadithService.listarConhecidos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3D2E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Hadiths Mais Conhecidos",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: FutureBuilder<List<HadithConhecido>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0B3D2E)),
            );
          }

          final itens = snapshot.data ?? [];

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: itens.length,
            separatorBuilder: (_, __) => const Divider(height: 32),
            itemBuilder: (context, index) => _HadithConhecidoCard(h: itens[index]),
          );
        },
      ),
    );
  }
}

class _HadithConhecidoCard extends StatelessWidget {
  final HadithConhecido h;

  const _HadithConhecidoCard({required this.h});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: const Border(
          left: BorderSide(color: Color(0xFF0B3D2E), width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.format_quote, size: 16, color: Color(0xFF0B3D2E)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  h.tema,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B3D2E),
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            h.arabe,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 20, height: 1.9),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: const Color(0xFFF0EAD6)),
          const SizedBox(height: 10),
          Text(
            h.traducaoPt,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 8),
          FutureBuilder<String>(
            future: HadithService.obterTextoIngles(h),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox();
              }
              return Text(
                snapshot.data!,
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                  height: 1.4,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.menu_book, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              const Text(
                "Sahih al-Bukhari",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HadithSecoesPage extends StatelessWidget {
  final HadithColecao colecao;

  const HadithSecoesPage({super.key, required this.colecao});

  @override
  Widget build(BuildContext context) {
    final secoes = colecao.secoes.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3D2E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(colecao.nome, style: const TextStyle(color: Colors.white)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: secoes.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final secao = secoes[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: const Color(0xFF0B3D2E),
              child: Text("${secao.key}"),
            ),
            title: Text(secao.value),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HadithListaPage(
                  colecao: colecao,
                  secaoId: secao.key,
                  tituloSecao: secao.value,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class HadithListaPage extends StatefulWidget {
  final HadithColecao colecao;
  final int secaoId;
  final String tituloSecao;

  const HadithListaPage({
    super.key,
    required this.colecao,
    required this.secaoId,
    required this.tituloSecao,
  });

  @override
  State<HadithListaPage> createState() => _HadithListaPageState();
}

class _HadithListaPageState extends State<HadithListaPage> {
  late Future<List<Hadith>> _futureHadiths;

  @override
  void initState() {
    super.initState();
    _futureHadiths =
        HadithService.obterSecao(widget.colecao.id, widget.secaoId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3D2E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.tituloSecao,
          style: const TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: FutureBuilder<List<Hadith>>(
        future: _futureHadiths,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0B3D2E)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      "Não foi possível carregar os hadiths.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {
                        _futureHadiths = HadithService.obterSecao(
                          widget.colecao.id,
                          widget.secaoId,
                        );
                      }),
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

          final hadiths = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: hadiths.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final h = hadiths[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B3D2E),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Hadith ${h.numero}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(h.texto, style: const TextStyle(fontSize: 15, height: 1.5)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
