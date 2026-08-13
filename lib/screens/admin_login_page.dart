import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // Login do admin principal (username + senha criados no registo)
  bool _usarLoginMesquita = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _mostrarSenha = false;
  bool _loadingMesquita = false;
  String _erroMesquita = "";

  @override
  void dispose() {
    _pinController.dispose();
    _usernameController.dispose();
    _senhaController.dispose();
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
    final username = _usernameController.text.trim();
    final senha = _senhaController.text;

    if (username.isEmpty || senha.isEmpty) {
      setState(() => _erroMesquita = "Preencha o utilizador e a senha");
      return;
    }

    setState(() {
      _loadingMesquita = true;
      _erroMesquita = "";
    });

    try {
      final credencial = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: MesquitaRegistoService.emailAuthParaUsername(username),
        password: senha,
      );

      final uid = credencial.user!.uid;
      final status = await MesquitaRegistoService.statusParaUid(uid);

      if (status != "aprovado") {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() {
          _loadingMesquita = false;
          _erroMesquita = switch (status) {
            "pendente" =>
              "O seu registo ainda está a aguardar aprovação do administrador.",
            "rejeitado" => "O pedido de registo desta mesquita foi rejeitado.",
            _ => "Conta não associada a nenhuma mesquita.",
          };
        });
        return;
      }

      if (!mounted) return;
      setState(() => _loadingMesquita = false);
      await widget.onSuccessMesquita!(uid);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMesquita = false;
        _erroMesquita = switch (e.code) {
          'user-not-found' || 'invalid-credential' || 'wrong-password' =>
            "Utilizador ou senha incorrectos.",
          'network-request-failed' => "Sem ligação à internet.",
          _ => "Erro ao entrar (${e.code}).",
        };
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
      TextField(
        controller: _usernameController,
        decoration: const InputDecoration(
          labelText: "Nome de utilizador",
          prefixIcon: Icon(Icons.person_outline),
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _senhaController,
        obscureText: !_mostrarSenha,
        decoration: InputDecoration(
          labelText: "Senha",
          prefixIcon: const Icon(Icons.lock_outline),
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: Icon(_mostrarSenha ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
          ),
        ),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loadingMesquita ? null : _loginMesquita,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0B3D2E),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _loadingMesquita
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("Entrar",
                  style: TextStyle(color: Colors.white, fontSize: 16)),
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
