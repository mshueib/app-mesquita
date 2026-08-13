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

  // Credenciais
  final _usernameCtrl = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordCtrl = TextEditingController();
  final _confirmarSenhaCtrl = TextEditingController();

  bool? _usernameDisponivel;
  bool _verificandoUsername = false;

  bool _enviando = false;
  bool _enviado = false;

  static final RegExp _telefoneRegex = RegExp(r'^[+]?[0-9\s-]{7,20}$');
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _usernameRegex = RegExp(r'^[a-zA-Z0-9._-]{3,20}$');

  @override
  void initState() {
    super.initState();
    _nomeMesquitaCtrl = TextEditingController(text: widget.nomeInicial ?? "");
    _usernameFocus.addListener(_onUsernameFocusChanged);
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
    _usernameFocus.removeListener(_onUsernameFocusChanged);
    _usernameFocus.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmarSenhaCtrl.dispose();
    super.dispose();
  }

  void _onUsernameFocusChanged() {
    if (_usernameFocus.hasFocus) return;
    _verificarUsername();
  }

  Future<void> _verificarUsername() async {
    final username = _usernameCtrl.text.trim();
    if (!_usernameRegex.hasMatch(username)) {
      setState(() => _usernameDisponivel = null);
      return;
    }

    setState(() => _verificandoUsername = true);
    try {
      final disponivel = await MesquitaRegistoService.usernameDisponivel(username);
      if (!mounted) return;
      setState(() {
        _usernameDisponivel = disponivel;
        _verificandoUsername = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _verificandoUsername = false);
    }
  }

  Future<void> _submeter() async {
    final formValido = _formKey.currentState!.validate();

    setState(() {
      _erroPais = _paisSelecionado == null ? "Selecione o país" : null;
    });

    if (!formValido || _erroPais != null) return;

    if (_cargo == "Outro" && _cargoOutroCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Indique o cargo na mesquita")),
      );
      return;
    }

    setState(() => _enviando = true);

    final disponivel =
        await MesquitaRegistoService.usernameDisponivel(_usernameCtrl.text.trim());

    if (!disponivel) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _usernameDisponivel = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Esse nome de utilizador já está em uso. Escolha outro."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final cargoFinal =
        _cargo == "Outro" ? _cargoOutroCtrl.text.trim() : (_cargo ?? "");

    try {
      await MesquitaRegistoService.registar(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
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

  Widget _campoUsername() {
    Widget? sufixo;
    if (_verificandoUsername) {
      sufixo = const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (_usernameDisponivel == true) {
      sufixo = const Icon(Icons.check_circle, color: Colors.green);
    } else if (_usernameDisponivel == false) {
      sufixo = const Icon(Icons.cancel, color: Colors.red);
    }

    return _campo(
      _usernameCtrl,
      "Nome de utilizador",
      Icons.person_outline,
      focusNode: _usernameFocus,
      suffixIcon: sufixo,
      helper: "Um nome, sem espaços (ex: ahmed.imane)",
      validador: (v) {
        if (v == null || v.trim().isEmpty) return "Campo obrigatório";
        if (!_usernameRegex.hasMatch(v.trim())) {
          return "Sem espaços — só letras, números, ponto, hífen ou underscore";
        }
        if (_usernameDisponivel == false) return "Nome de utilizador em uso";
        return null;
      },
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
            _tituloSeccao("Credenciais de Acesso"),
            _campoUsername(),
            _campo(
              _passwordCtrl,
              "Senha",
              Icons.lock_outline,
              obscure: true,
              validador: (v) {
                if (v == null || v.isEmpty) return "Campo obrigatório";
                if (v.length < 8) return "Mínimo 8 caracteres";
                return null;
              },
            ),
            _campo(
              _confirmarSenhaCtrl,
              "Confirmar senha",
              Icons.lock_outline,
              obscure: true,
              validador: (v) {
                if (v == null || v.isEmpty) return "Campo obrigatório";
                if (v != _passwordCtrl.text) return "As senhas não coincidem";
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
        ),
      ),
    );
  }
}
