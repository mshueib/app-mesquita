import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminLoginPage extends StatefulWidget {
  final VoidCallback onSuccess;

  const AdminLoginPage({super.key, required this.onSuccess});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final TextEditingController _passwordController = TextEditingController();
  String _erro = "";
  bool _mostrarSenha = false;

  Future<void> _login() async {
    bool sucesso = AuthService.login(_passwordController.text.trim());

    if (sucesso) {
      try {
        // 🔐 Autenticar no Firebase (anónimo)
        await FirebaseAuth.instance.signInAnonymously();

        widget.onSuccess();
      } catch (e) {
        setState(() {
          _erro = "Erro ao autenticar no servidor.";
        });
      }
    } else {
      setState(() {
        _erro = "Senha incorreta";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Acesso Administrativo",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            obscureText: !_mostrarSenha,
            decoration: InputDecoration(
              labelText: "Senha",
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _mostrarSenha ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _mostrarSenha = !_mostrarSenha;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              await _login();
            },
            child: const Text("Entrar"),
          ),
          const SizedBox(height: 10),
          if (_erro.isNotEmpty)
            Text(
              _erro,
              style: const TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }
}
