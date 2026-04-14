import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class MesquitasPage extends StatefulWidget {
  final Function(String) onSelecionar;

  const MesquitasPage({super.key, required this.onSelecionar});

  @override
  State<MesquitasPage> createState() => _MesquitasPageState();
}

class _MesquitasPageState extends State<MesquitasPage> {
  List<Map<String, dynamic>> _mesquitas = [];

  @override
  void initState() {
    super.initState();
    _carregarMesquitas();
  }

  void _carregarMesquitas() async {
    final ref = FirebaseDatabase.instance.ref("mesquitas");
    final snapshot = await ref.get();

    if (!snapshot.exists) return;

    final data = Map<String, dynamic>.from(snapshot.value as Map);

    List<Map<String, dynamic>> temp = [];

    data.forEach((key, value) {
      temp.add({
        "id": key,
        "nome": value['nome'] ?? "Sem nome",
        "cidade": value['cidade'] ?? "",
      });
    });

    setState(() {
      _mesquitas = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Masjids"),
        backgroundColor: const Color.fromARGB(255, 38, 88, 71),
      ),
      body: ListView.builder(
        itemCount: _mesquitas.length,
        itemBuilder: (context, index) {
          final m = _mesquitas[index];

          return ListTile(
            title: Text(m['nome']),
            subtitle: Text(m['cidade']),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              widget.onSelecionar(m['id']);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}
