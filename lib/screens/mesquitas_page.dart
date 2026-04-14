import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'registo_mesquita_page.dart';

class MesquitasPage extends StatefulWidget {
  final Function(String) onSelecionar;

  const MesquitasPage({super.key, required this.onSelecionar});

  @override
  State<MesquitasPage> createState() => _MesquitasPageState();
}

class _MesquitasPageState extends State<MesquitasPage> {
  List<Map<String, dynamic>> _mesquitas = [];
  List<Map<String, dynamic>> _filtradas = [];
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarMesquitas();
    _searchCtrl.addListener(_filtrar);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _carregarMesquitas() async {
    final ref = FirebaseDatabase.instance.ref("mesquitas");
    final snapshot = await ref.get();

    if (!snapshot.exists) return;

    final data = Map<String, dynamic>.from(snapshot.value as Map);

    List<Map<String, dynamic>> temp = [];

    data.forEach((key, value) {
      if (value['status'] == null || value['status'] == 'ativo') {
        temp.add({
          "id": key,
          "nome": value['nome'] ?? "Sem nome",
          "cidade": value['cidade'] ?? "",
          "pais": value['pais'] ?? "",
        });
      }
    });

    setState(() {
      _mesquitas = temp;
      _filtradas = temp;
    });
  }

  void _filtrar() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtradas = _mesquitas.where((m) {
        return m['nome'].toLowerCase().contains(q) ||
            m['cidade'].toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EA),
      appBar: AppBar(
        title: const Text("Masjids"),
        backgroundColor: const Color(0xFF0B3D2E),
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Pesquisar mesquita ou cidade...",
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.6), fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // banner "brevemente disponível" no topo
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD4AF37),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.add_business,
                    color: Color(0xFFB8860B), size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Registar a sua mesquita — brevemente disponível",
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8B6F00),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "Em breve",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filtradas.isEmpty
                ? const Center(
                    child: Text(
                      "Nenhuma mesquita encontrada",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    itemCount: _filtradas.length,
                    itemBuilder: (context, index) {
                      final m = _filtradas[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B3D2E).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.mosque,
                                color: Color(0xFF0B3D2E), size: 20),
                          ),
                          title: Text(
                            m['nome'],
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Text(
                            "${m['cidade']}${m['pais'].isNotEmpty ? ', ${m['pais']}' : ''}",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              size: 14, color: Colors.grey),
                          onTap: () {
                            widget.onSelecionar(m['id']);
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
