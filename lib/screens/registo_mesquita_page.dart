import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class RegistoMesquitaPage extends StatefulWidget {
  const RegistoMesquitaPage({super.key});

  @override
  State<RegistoMesquitaPage> createState() => _RegistoMesquitaPageState();
}

class _RegistoMesquitaPageState extends State<RegistoMesquitaPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();
  final _paisCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _mensagemCtrl = TextEditingController();
  bool _enviando = false;
  bool _enviado = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cidadeCtrl.dispose();
    _paisCtrl.dispose();
    _emailCtrl.dispose();
    _telefoneCtrl.dispose();
    _mensagemCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);

    try {
      await FirebaseDatabase.instance.ref("pedidos_registo").push().set({
        "nome": _nomeCtrl.text.trim(),
        "cidade": _cidadeCtrl.text.trim(),
        "pais": _paisCtrl.text.trim(),
        "email": _emailCtrl.text.trim(),
        "telefone": _telefoneCtrl.text.trim(),
        "mensagem": _mensagemCtrl.text.trim(),
        "status": "pendente",
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      });

      setState(() {
        _enviando = false;
        _enviado = true;
      });
    } catch (e) {
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erro ao enviar pedido. Tente novamente."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _campo(
    TextEditingController ctrl,
    String label,
    IconData icone, {
    TextInputType tipo = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validador,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        keyboardType: tipo,
        maxLines: maxLines,
        validator: validador ??
            (v) => (v == null || v.trim().isEmpty) ? "Campo obrigatório" : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icone, color: const Color(0xFF0B3D2E)),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF0B3D2E), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
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
        foregroundColor: Colors.white,
        title: const Text("Registar Mesquita"),
      ),
      body: _enviado ? _sucesso() : _formulario(),
    );
  }

  Widget _sucesso() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF0B3D2E).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF0B3D2E),
                size: 44,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Pedido enviado!",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B3D2E),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "O seu pedido foi recebido e será analisado pelo administrador. Receberá uma resposta no email fornecido.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B3D2E),
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                "Voltar",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0B3D2E).withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF0B3D2E).withOpacity(0.15),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF0B3D2E), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Preencha o formulário para solicitar o registo da sua mesquita. O pedido será analisado pelo administrador.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0B3D2E),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Informações da Mesquita",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            _campo(_nomeCtrl, "Nome da Mesquita", Icons.mosque),
            _campo(_cidadeCtrl, "Cidade", Icons.location_city),
            _campo(_paisCtrl, "País", Icons.flag),
            const SizedBox(height: 8),
            const Text(
              "Contacto do Responsável",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            _campo(
              _emailCtrl,
              "Email",
              Icons.email_outlined,
              tipo: TextInputType.emailAddress,
              validador: (v) {
                if (v == null || v.trim().isEmpty) {
                  return "Campo obrigatório";
                }
                if (!v.contains("@")) {
                  return "Email inválido";
                }
                return null;
              },
            ),
            _campo(
              _telefoneCtrl,
              "Telefone",
              Icons.phone_outlined,
              tipo: TextInputType.phone,
            ),
            _campo(
              _mensagemCtrl,
              "Mensagem (opcional)",
              Icons.message_outlined,
              maxLines: 3,
              validador: (_) => null,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _enviando ? null : _enviar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B3D2E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Enviar Pedido",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
