import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/mesquita_registo_service.dart';

class AdminLoginPage extends StatefulWidget {
  final VoidCallback onSuccess;
  final Future<bool> Function(String pin)? loginFn;
  final String titulo;

  /// Quando true, mostra também a opção de entrar com o username/senha
  /// criados no registo da mesquita (o "admin principal").
  final bool mostrarLoginMesquita;

  /// Chamado quando o admin principal de uma mesquita aprovada entra
  /// com sucesso — recebe o UID (== ID da mesquita).
  final Future<void> Function(String uid)? onSuccessMesquita;

  const AdminLoginPage({
    super.key,
    required this.onSuccess,
    this.loginFn,
    this.titulo = "Acesso Administrativo",
    this.mostrarLoginMesquita = false,
    this.onSuccessMesquita,
  });

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  // Login por PIN (mesquita atualmente aberta / super-admin)
  final TextEditingController _pinController = TextEditingController();
  String _erro = "";
  bool _mostrarPin = false;
  bool _loading = false;
  int _tentativas = 0;
  bool _bloqueado = false;

  // Login do admin principal (mesma conta Google usada no registo)
  bool _usarLoginMesquita = false;
  bool _loadingMesquita = false;
  String _erroMesquita = "";

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_bloqueado) return;

    setState(() {
      _loading = true;
      _erro = "";
    });

    final loginFn = widget.loginFn ?? AuthService.login;
    bool sucesso = await loginFn(_pinController.text.trim());

    setState(() => _loading = false);

    if (sucesso) {
      _tentativas = 0;
      widget.onSuccess();
    } else {
      _tentativas++;

      if (_tentativas >= 5) {
        setState(() {
          _bloqueado = true;
          _erro = "Demasiadas tentativas. Tente mais tarde.";
        });

        Future.delayed(const Duration(minutes: 2), () {
          if (mounted) {
            setState(() {
              _bloqueado = false;
              _tentativas = 0;
              _erro = "";
            });
          }
        });
      } else {
        setState(() {
          _erro = "PIN incorrecto. Tentativa $_tentativas de 5.";
        });
      }
    }
  }

  Future<void> _loginMesquita() async {
    setState(() {
      _loadingMesquita = true;
      _erroMesquita = "";
    });

    try {
      final user = await MesquitaRegistoService.entrarComGoogle();
      final uid = user.uid;
      final status = await MesquitaRegistoService.statusParaUid(uid);

      if (status != "aprovado") {
        await MesquitaRegistoService.sairGoogle();
        if (!mounted) return;
        setState(() {
          _loadingMesquita = false;
          _erroMesquita = switch (status) {
            "pendente" =>
              "O seu registo ainda está a aguardar aprovação do administrador.",
            "rejeitado" => "O pedido de registo desta mesquita foi rejeitado.",
            _ => "Conta Google não associada a nenhuma mesquita.",
          };
        });
        return;
      }

      if (!mounted) return;
      setState(() => _loadingMesquita = false);
      await widget.onSuccessMesquita!(uid);
    } on MesquitaRegistoException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMesquita = false;
        _erroMesquita = e.mensagem;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMesquita = false;
        _erroMesquita = "Erro inesperado. Tente novamente.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.admin_panel_settings,
            size: 60,
            color: Color(0xFF0B3D2E),
          ),
          const SizedBox(height: 16),
          Text(
            widget.titulo,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          if (!_usarLoginMesquita) ..._campoPin() else ..._camposMesquita(),
          if (widget.mostrarLoginMesquita) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() {
                _usarLoginMesquita = !_usarLoginMesquita;
                _erro = "";
                _erroMesquita = "";
              }),
              child: Text(
                _usarLoginMesquita
                    ? "Entrar com o PIN da mesquita"
                    : "Sou administrador de uma mesquita registada",
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _campoPin() {
    return [
      TextField(
        controller: _pinController,
        obscureText: !_mostrarPin,
        keyboardType: TextInputType.number,
        maxLength: 10,
        enabled: !_bloqueado,
        decoration: InputDecoration(
          labelText: "Código PIN",
          border: const OutlineInputBorder(),
          counterText: "",
          suffixIcon: IconButton(
            icon: Icon(_mostrarPin ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _mostrarPin = !_mostrarPin),
          ),
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (_loading || _bloqueado) ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0B3D2E),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _loading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("Entrar",
                  style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ),
      const SizedBox(height: 12),
      if (_erro.isNotEmpty)
        Text(
          _erro,
          style: TextStyle(
            color: _bloqueado ? Colors.orange : Colors.red,
            fontWeight: FontWeight.w500,
          ),
        ),
    ];
  }

  List<Widget> _camposMesquita() {
    return [
      const Text(
        "Entre com a conta Google usada no registo da mesquita.",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: Colors.grey),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _loadingMesquita ? null : _loginMesquita,
          icon: _loadingMesquita
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.g_mobiledata,
                  size: 28, color: Color(0xFF0B3D2E)),
          label: const Text("Entrar com Google"),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0B3D2E),
            side: const BorderSide(color: Color(0xFF0B3D2E)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      const SizedBox(height: 12),
      if (_erroMesquita.isNotEmpty)
        Text(
          _erroMesquita,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
        ),
    ];
  }
}
