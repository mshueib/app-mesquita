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
  final TextEditingController _oradorController = TextEditingController();
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

    _oradorController.text =
        widget.dadosAtuais['orador_jummah']?.toString() ?? "";
  }

  void _carregarAvisos() {
    _avisos.clear();
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: tipo,
              items: const [
                DropdownMenuItem(value: 'geral', child: Text("Aviso Geral")),
                DropdownMenuItem(value: 'janazah', child: Text("Janazah")),
                DropdownMenuItem(value: 'nikah', child: Text("Nikah")),
              ],
              onChanged: (v) => tipo = v ?? 'geral',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: textoCtrl,
              decoration: const InputDecoration(labelText: "Texto do Aviso"),
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

    dados['orador_jummah'] = _oradorController.text;

    await widget.dbRef.update(dados);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Dados gravados com sucesso"),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _descartarAlteracoes() {
    setState(() {
      _inicializarCampos();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Alterações descartadas"),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Widget _campo(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _ctrl[key],
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
      backgroundColor: const Color(0xFFF4F1EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3D2E),
        title: const Text(
          "Painel Administrativo",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B3D2E),
              ),
            ),
            const SizedBox(height: 10),
            ..._avisos.map(_buildAvisoItem),
          ]),
          _secao("👤 Orador de Jumu'ah", [
            TextField(
              controller: _oradorController,
              decoration: InputDecoration(
                labelText: "Nome do Orador",
                filled: true,
                fillColor: Colors.white,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
          _secao("📅 Calendário", [
            // 🔽 MÊS ISLÂMICO DROPDOWN
            DropdownButtonFormField<String>(
              value: _ctrl['mes_islamico']!.text.isNotEmpty
                  ? _ctrl['mes_islamico']!.text
                  : null,
              items: const [
                "Muharram",
                "Safar",
                "Rabi al-Awwal",
                "Rabi al-Thani",
                "Jumada al-Awwal",
                "Jumada al-Thani",
                "Rajab",
                "Sha'ban",
                "Ramadhan",
                "Shawwal",
                "Dhul Qa'dah",
                "Dhul Hijjah",
              ]
                  .map((mes) => DropdownMenuItem(
                        value: mes,
                        child: Text(mes),
                      ))
                  .toList(),
              onChanged: (v) {
                _ctrl['mes_islamico']!.text = v ?? "";
              },
              decoration: InputDecoration(
                labelText: "Mês Islâmico",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 🔢 ANO
            _campo('ano_islamico', "Ano Hijri"),

            const SizedBox(height: 14),

            // 🔽 DIA 1–30 DROPDOWN
            DropdownButtonFormField<String>(
              value:
                  _ctrl['jejum']!.text.isNotEmpty ? _ctrl['jejum']!.text : null,
              items: List.generate(
                30,
                (index) => DropdownMenuItem(
                  value: (index + 1).toString(),
                  child: Text((index + 1).toString()),
                ),
              ),
              onChanged: (v) {
                _ctrl['jejum']!.text = v ?? "";
              },
              decoration: InputDecoration(
                labelText: "Dia",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 14),

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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _descartarAlteracoes,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text(
                    "DESCARTAR",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _gravar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B3D2E),
                  ),
                  child: const Text("GRAVAR"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
