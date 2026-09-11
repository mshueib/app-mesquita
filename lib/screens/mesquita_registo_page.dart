import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import '../services/mesquita_registo_service.dart';

const List<String> _cargosDisponiveis = [
  "Imã",
  "Presidente do Conselho",
  "Secretário",
  "Outro",
];

class MesquitaRegistoPage extends StatefulWidget {
  /// Pré-preenche o nome da mesquita (ex: vindo do termo pesquisado
  /// quando a pesquisa não encontra resultados).
  final String? nomeInicial;

  const MesquitaRegistoPage({super.key, this.nomeInicial});

  @override
  State<MesquitaRegistoPage> createState() => _MesquitaRegistoPageState();
}

class _MesquitaRegistoPageState extends State<MesquitaRegistoPage> {
  final _formKey = GlobalKey<FormState>();

  // Requerente
  final _nomeRequerenteCtrl = TextEditingController();
  final _telefoneRequerenteCtrl = TextEditingController();
  final _emailRequerenteCtrl = TextEditingController();
  String? _cargo;
  final _cargoOutroCtrl = TextEditingController();

  // Localização
  Country? _paisSelecionado;
  String? _erroPais;
  final _cidadeCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();

  // Mesquita
  late final TextEditingController _nomeMesquitaCtrl;
  final _contactoMesquitaCtrl = TextEditingController();
  final _emailMesquitaCtrl = TextEditingController();

  // Autenticação Google
  bool _googleConectado = false;
  bool _entrandoGoogle = false;
  String? _emailGoogleConectado;

  bool _enviando = false;
  bool _enviado = false;

  static final RegExp _telefoneRegex = RegExp(r'^[+]?[0-9\s-]{7,20}$');
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    _nomeMesquitaCtrl = TextEditingController(text: widget.nomeInicial ?? "");
  }

  @override
  void dispose() {
    _nomeRequerenteCtrl.dispose();
    _telefoneRequerenteCtrl.dispose();
    _emailRequerenteCtrl.dispose();
    _cargoOutroCtrl.dispose();
    _cidadeCtrl.dispose();
    _bairroCtrl.dispose();
    _enderecoCtrl.dispose();
    _nomeMesquitaCtrl.dispose();
    _contactoMesquitaCtrl.dispose();
    _emailMesquitaCtrl.dispose();
    super.dispose();
  }

  Future<void> _continuarComGoogle() async {
    setState(() => _entrandoGoogle = true);
    try {
      final user = await MesquitaRegistoService.entrarComGoogle();
      if (!mounted) return;
      setState(() {
        _googleConectado = true;
        _emailGoogleConectado = user.email;
        _entrandoGoogle = false;
        if (_nomeRequerenteCtrl.text.trim().isEmpty) {
          _nomeRequerenteCtrl.text = user.displayName ?? "";
        }
        if (_emailRequerenteCtrl.text.trim().isEmpty) {
          _emailRequerenteCtrl.text = user.email ?? "";
        }
      });
    } on MesquitaRegistoException catch (e) {
      if (!mounted) return;
      setState(() => _entrandoGoogle = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensagem), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _submeter() async {
    final formValido = _formKey.currentState!.validate();

    setState(() {
      _erroPais = _paisSelecionado == null ? "Selecione o país" : null;
    });

    if (!formValido || _erroPais != null) return;

    if (!_googleConectado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Entre com o Google para continuar")),
      );
      return;
    }

    if (_cargo == "Outro" && _cargoOutroCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Indique o cargo na mesquita")),
      );
      return;
    }

    setState(() => _enviando = true);

    final cargoFinal =
        _cargo == "Outro" ? _cargoOutroCtrl.text.trim() : (_cargo ?? "");

    try {
      await MesquitaRegistoService.registar(
        nomeRequerente: _nomeRequerenteCtrl.text,
        telefoneRequerente: _telefoneRequerenteCtrl.text,
        emailRequerente: _emailRequerenteCtrl.text,
        cargo: cargoFinal,
        pais: _paisSelecionado!.name,
        cidade: _cidadeCtrl.text,
        bairro: _bairroCtrl.text,
        endereco: _enderecoCtrl.text,
        nomeMesquita: _nomeMesquitaCtrl.text,
        contactoMesquita: _contactoMesquitaCtrl.text,
        emailMesquita: _emailMesquitaCtrl.text,
      );

      if (!mounted) return;
      setState(() {
        _enviando = false;
        _enviado = true;
      });
    } on MesquitaRegistoException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensagem), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erro inesperado. Tente novamente."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _abrirSeletorPais() {
    showCountryPicker(
      context: context,
      favorite: const ['MZ'],
      searchAutofocus: true,
      onSelect: (country) {
        setState(() {
          _paisSelecionado = country;
          _erroPais = null;
        });
      },
    );
  }

  InputDecoration _decoracao(String label, IconData icone, {String? helper}) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      prefixIcon: Icon(icone, color: const Color(0xFF0B3D2E)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    );
  }

  Widget _campo(
    TextEditingController ctrl,
    String label,
    IconData icone, {
    TextInputType tipo = TextInputType.text,
    int maxLines = 1,
    bool obscure = false,
    FocusNode? focusNode,
    Widget? suffixIcon,
    String? helper,
    String? Function(String?)? validador,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        focusNode: focusNode,
        keyboardType: tipo,
        maxLines: maxLines,
        obscureText: obscure,
        validator: validador ??
            (v) => (v == null || v.trim().isEmpty) ? "Campo obrigatório" : null,
        decoration: _decoracao(label, icone, helper: helper).copyWith(
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _tituloSeccao(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
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
      body: _enviado ? _telaSucesso() : _formulario(),
    );
  }

  Widget _telaSucesso() {
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
              "Registo submetido!",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B3D2E),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "O seu registo foi submetido e está a aguardar aprovação do administrador.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.6),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B3D2E),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  "Voltar à pesquisa",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoPais() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _abrirSeletorPais,
        child: InputDecorator(
          decoration: _decoracao("País", Icons.flag).copyWith(
            errorText: _erroPais,
          ),
          child: Text(
            _paisSelecionado == null
                ? "Selecionar país"
                : "${_paisSelecionado!.flagEmoji}  ${_paisSelecionado!.name}",
            style: TextStyle(
              color: _paisSelecionado == null ? Colors.grey[600] : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _campoCargo() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _cargo,
            decoration: _decoracao("Cargo na mesquita", Icons.badge_outlined),
            items: _cargosDisponiveis
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _cargo = v),
            validator: (v) => v == null ? "Selecione o cargo" : null,
          ),
          if (_cargo == "Outro")
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _campo(
                _cargoOutroCtrl,
                "Qual o cargo?",
                Icons.edit_outlined,
              ),
            ),
        ],
      ),
    );
  }

  Widget _cartaoGoogle() {
    if (_googleConectado) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Sessão Google ligada: ${_emailGoogleConectado ?? ''}",
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0B3D2E).withOpacity(0.15)),
      ),
      child: Column(
        children: [
          const Icon(Icons.mosque, color: Color(0xFF0B3D2E), size: 36),
          const SizedBox(height: 12),
          const Text(
            "Entre com a sua conta Google para começar o registo da mesquita.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _entrandoGoogle ? null : _continuarComGoogle,
              icon: _entrandoGoogle
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.g_mobiledata,
                      size: 28, color: Color(0xFF0B3D2E)),
              label: const Text("Continuar com Google"),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0B3D2E),
                side: const BorderSide(color: Color(0xFF0B3D2E)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
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
                      "Preencha o formulário para registar a sua mesquita. O registo fica pendente até ser aprovado pelo administrador.",
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
            const SizedBox(height: 20),
            _cartaoGoogle(),
            if (_googleConectado) ...[
              _tituloSeccao("Dados do Requerente"),
              _campo(_nomeRequerenteCtrl, "Nome completo", Icons.person_outline),
              _campo(
                _telefoneRequerenteCtrl,
                "Contacto telefónico",
                Icons.phone_outlined,
                tipo: TextInputType.phone,
                validador: (v) {
                  if (v == null || v.trim().isEmpty) return "Campo obrigatório";
                  if (!_telefoneRegex.hasMatch(v.trim())) {
                    return "Número de telefone inválido";
                  }
                  return null;
                },
              ),
              _campo(
                _emailRequerenteCtrl,
                "Email (opcional)",
                Icons.email_outlined,
                tipo: TextInputType.emailAddress,
                validador: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (!_emailRegex.hasMatch(v.trim())) return "Email inválido";
                  return null;
                },
              ),
              _campoCargo(),
              _tituloSeccao("Localização"),
              _campoPais(),
              _campo(_cidadeCtrl, "Cidade", Icons.location_city),
              _campo(_bairroCtrl, "Localidade/Bairro", Icons.place_outlined),
              _campo(
                _enderecoCtrl,
                "Endereço completo (opcional)",
                Icons.map_outlined,
                validador: (_) => null,
              ),
              _tituloSeccao("Dados da Mesquita"),
              _campo(_nomeMesquitaCtrl, "Nome da mesquita", Icons.mosque),
              _campo(
                _contactoMesquitaCtrl,
                "Contacto da mesquita (telefone/WhatsApp)",
                Icons.chat_outlined,
                tipo: TextInputType.phone,
                validador: (v) {
                  if (v == null || v.trim().isEmpty) return "Campo obrigatório";
                  if (!_telefoneRegex.hasMatch(v.trim())) {
                    return "Número de telefone inválido";
                  }
                  return null;
                },
              ),
              _campo(
                _emailMesquitaCtrl,
                "Email da mesquita (opcional)",
                Icons.email_outlined,
                tipo: TextInputType.emailAddress,
                validador: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (!_emailRegex.hasMatch(v.trim())) return "Email inválido";
                  return null;
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _enviando ? null : _submeter,
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
                          "Registar Mesquita",
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
          ],
        ),
      ),
    );
  }
}
