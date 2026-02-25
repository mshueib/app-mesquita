import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class AdminPanelPage extends StatefulWidget {
  final DatabaseReference dbRef;
  final Map<String, dynamic> dadosAtuais;

  const AdminPanelPage({
    super.key,
    required this.dbRef,
    required this.dadosAtuais,
  });

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final Map<String, TextEditingController> _ctrls = {};
  String? _mesSel;
  String? _diaSel;

  final List<String> _meses = [
    "Muharram",
    "Safar",
    "Rabi' al-Awwal",
    "Rabi' al-Thani",
    "Jumada al-Ula",
    "Jumada al-Akhira",
    "Rajab",
    "Sha'ban",
    "Ramadhan",
    "Shawwal",
    "Dhu al-Qi'dah",
    "Dhu al-Hijjah"
  ];

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    final campos = [
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
      'orador_jummah',
      'aviso_geral',
      'prazo_geral',
      'aviso_janazah',
      'prazo_janazah',
      'sehri',
      'iftar',
      'ano_islamico'
    ];

    for (var k in campos) {
      _ctrls[k] = TextEditingController(
        text: widget.dadosAtuais[k]?.toString() ?? "",
      );
    }

    String mesBanco =
        widget.dadosAtuais['mes_islamico']?.toString() ?? "Ramadhan";

    _mesSel = _meses.firstWhere(
      (m) => m.toLowerCase() == mesBanco.toLowerCase(),
      orElse: () => "Ramadhan",
    );

    _diaSel = widget.dadosAtuais['jejum']?.toString() ?? "1";

    if (int.tryParse(_diaSel!) == null || int.parse(_diaSel!) > 30) {
      _diaSel = "1";
    }
  }

  Future<void> _pickData(String k) async {
    DateTime? d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (d != null) {
      setState(() {
        _ctrls[k]?.text = DateFormat('yyyy-MM-dd').format(d);
      });
    }
  }

  void _salvar() async {
    Map<String, dynamic> up = {};

    _ctrls.forEach((k, v) => up[k] = v.text);

    up['mes_islamico'] = _mesSel;
    up['jejum'] = _diaSel;

    await widget.dbRef.update(up);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.green,
        content: Text("Dados gravados no Firebase!"),
      ),
    );
  }

  Widget _campo(String k, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: _ctrls[k],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _campoData(String k, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: _ctrls[k],
        readOnly: true,
        onTap: () => _pickData(k),
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _secao(String titulo, List<Widget> children) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
      child: ExpansionTile(
        title: Text(
          titulo,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF006400),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Painel Administrativo"),
        backgroundColor: const Color(0xFF006400),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _secao("Horários Salah", [
            _campo('fajr_azan', "Fajr Azan"),
            _campo('fajr_namaz', "Fajr Namaz"),
            _campo('dhuhr_azan', "Dhuhr Azan"),
            _campo('dhuhr_namaz', "Dhuhr Namaz"),
            _campo('asr_azan', "Asr Azan"),
            _campo('asr_namaz', "Asr Namaz"),
            _campo('maghrib_azan', "Maghrib Azan"),
            _campo('maghrib_namaz', "Maghrib Namaz"),
            _campo('isha_azan', "Isha Azan"),
            _campo('isha_namaz', "Isha Namaz"),
            _campo('orador_jummah', "Orador Jummah"),
          ]),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _salvar,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006400),
            ),
            child: const Text("GRAVAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
