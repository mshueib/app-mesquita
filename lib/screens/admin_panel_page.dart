import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class AdminPanelPage extends StatefulWidget {
  final DatabaseReference dbRef;
  final Map<String, dynamic> dadosAtuais;
  final VoidCallback onLogout;

  const AdminPanelPage({
    super.key,
    required this.dbRef,
    required this.dadosAtuais,
    required this.onLogout,
  });

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final Map<String, TextEditingController> _ctrl = {};

  final List<Map<String, dynamic>> _avisos = [];

  @override
  void initState() {
    super.initState();
    _inicializarCampos();
    _carregarAvisos();
  }

  void _inicializarCampos() {
    final campos = [
      'mes_islamico',
      'ano_islamico',
      'jejum',
      'sehri',
      'iftar',
      'fajr_azan',
      'fajr_namaz',
      'dhuhr_azan',
      'dhuhr_namaz',
      'asr_azan',
      'asr_namaz',
      'maghrib_azan',
      'maghrib_namaz',
      'isha_azan',
      'isha_namaz',
    ];

    for (var c in campos) {
      _ctrl[c] = TextEditingController(
        text: widget.dadosAtuais[c]?.toString() ?? "",
      );
    }
  }

  void _carregarAvisos() {
    if (widget.dadosAtuais.containsKey('avisos')) {
      Map avisosMap =
          Map<String, dynamic>.from(widget.dadosAtuais['avisos'] ?? {});

      avisosMap.forEach((key, value) {
        _avisos.add({
          'id': key,
          'tipo': value['tipo'],
          'texto': value['texto'],
          'prazo': value['prazo'],
        });
      });
    }
  }

  Future<void> _adicionarAvisoDialog() async {
    String tipo = 'geral';
    TextEditingController textoCtrl = TextEditingController();
    TextEditingController prazoCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Novo Aviso"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: tipo,
                items: const [
                  DropdownMenuItem(value: 'geral', child: Text("Aviso Geral")),
                  DropdownMenuItem(value: 'janazah', child: Text("Janazah")),
                  DropdownMenuItem(value: 'nikah', child: Text("Nikah")),
                ],
                onChanged: (v) => tipo = v ?? 'geral',
                decoration: const InputDecoration(labelText: "Tipo"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textoCtrl,
                decoration: const InputDecoration(
                  labelText: "Texto do Aviso",
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: prazoCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Prazo",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  DateTime? data = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2035),
                  );
                  if (data != null) {
                    prazoCtrl.text = DateFormat('yyyy-MM-dd').format(data);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              await widget.dbRef.child('avisos').push().set({
                'tipo': tipo,
                'texto': textoCtrl.text,
                'prazo': prazoCtrl.text,
              });
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text("Adicionar"),
          ),
        ],
      ),
    );
  }

  Future<void> _removerAviso(String id) async {
    await widget.dbRef.child('avisos').child(id).remove();
    setState(() {
      _avisos.removeWhere((a) => a['id'] == id);
    });
  }

  Future<void> _gravar() async {
    Map<String, dynamic> dados = {};
    _ctrl.forEach((key, value) {
      dados[key] = value.text;
    });

    await widget.dbRef.update(dados);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Dados gravados com sucesso"),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _campo(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _ctrl[key],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _secao(String titulo, List<Widget> filhos) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: ExpansionTile(
        title: Text(
          titulo,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Color(0xFF0B3D2E)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(children: filhos),
          )
        ],
      ),
    );
  }

  Widget _buildAvisoItem(Map aviso) {
    return Card(
      child: ListTile(
        title: Text(aviso['texto']),
        subtitle: Text("${aviso['tipo']} • Expira: ${aviso['prazo']}"),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _removerAviso(aviso['id']),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Painel Administrativo"),
        backgroundColor: const Color(0xFF0B3D2E),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _secao("📢 Avisos", [
            ElevatedButton.icon(
              onPressed: _adicionarAvisoDialog,
              icon: const Icon(Icons.add),
              label: const Text("Adicionar Aviso"),
            ),
            const SizedBox(height: 10),
            ..._avisos.map(_buildAvisoItem),
          ]),
          _secao("📅 Calendário", [
            _campo('mes_islamico', "Mês Islâmico"),
            _campo('ano_islamico', "Ano Hijri"),
            _campo('jejum', "Dia"),
            _campo('sehri', "Sehri"),
            _campo('iftar', "Iftar"),
          ]),
          _secao("🕌 Horários de Salah", [
            _campo('fajr_azan', "Fajr Azan"),
            _campo('fajr_namaz', "Fajr Jammah"),
            _campo('dhuhr_azan', "Dhuhr Azan"),
            _campo('dhuhr_namaz', "Dhuhr Jammah"),
            _campo('asr_azan', "Asr Azan"),
            _campo('asr_namaz', "Asr Jammah"),
            _campo('maghrib_azan', "Maghrib Azan"),
            _campo('maghrib_namaz', "Maghrib Jammah"),
            _campo('isha_azan', "Isha Azan"),
            _campo('isha_namaz', "Isha Jammah"),
          ]),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _gravar,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B3D2E)),
            child: const Text("GRAVAR"),
          ),
        ],
      ),
    );
  }
}
