import 'package:flutter/material.dart';
import '../services/dua_service.dart';

/// Lista de categorias de Duas/Dhikr — vive dentro do PageView
/// principal (sem AppBar própria).
class DuasPage extends StatefulWidget {
  const DuasPage({super.key});

  @override
  State<DuasPage> createState() => _DuasPageState();
}

class _DuasPageState extends State<DuasPage> {
  late Future<List<DuaCategoria>> _futureCategorias;

  @override
  void initState() {
    super.initState();
    _futureCategorias = DuaService.listarCategorias();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F1EA),
      child: FutureBuilder<List<DuaCategoria>>(
        future: _futureCategorias,
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
                    const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      "Não foi possível carregar as duas.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {
                        _futureCategorias = DuaService.listarCategorias();
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

          final categorias = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: categorias.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final categoria = categorias[index];
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF0B3D2E),
                    child: Icon(Icons.volunteer_activism, color: Colors.white),
                  ),
                  title: Text(
                    categoria.nome,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("${categoria.total} duas"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DuaListaPage(categoria: categoria),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class DuaListaPage extends StatefulWidget {
  final DuaCategoria categoria;

  const DuaListaPage({super.key, required this.categoria});

  @override
  State<DuaListaPage> createState() => _DuaListaPageState();
}

class _DuaListaPageState extends State<DuaListaPage> {
  late Future<List<Dua>> _futureDuas;

  @override
  void initState() {
    super.initState();
    _futureDuas = DuaService.obterCategoria(widget.categoria.slug);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3D2E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.categoria.nome,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: FutureBuilder<List<Dua>>(
        future: _futureDuas,
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
                    const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      "Não foi possível carregar as duas.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {
                        _futureDuas = DuaService.obterCategoria(widget.categoria.slug);
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

          final duas = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: duas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final dua = duas[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: const Border(
                    left: BorderSide(color: Color(0xFFD4AF37), width: 4),
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
                  if (dua.titulo.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.volunteer_activism,
                            size: 16, color: Color(0xFFB8860B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            dua.titulo,
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
                  if (dua.arabe.isNotEmpty)
                    Text(
                      dua.arabe,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 21, height: 1.9),
                    ),
                  if (dua.latim.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      dua.latim,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Container(height: 1, color: const Color(0xFFF0EAD6)),
                  const SizedBox(height: 10),
                  Text(dua.traducao, style: const TextStyle(fontSize: 15, height: 1.5)),
                  if (dua.notas.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        dua.notas,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB8860B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (dua.fonte.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      dua.fonte,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
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
