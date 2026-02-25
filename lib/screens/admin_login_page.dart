import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AdminLoginPage extends StatefulWidget {
  final VoidCallback onSuccess;

  const AdminLoginPage({super.key, required this.onSuccess});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final TextEditingController _passwordController = TextEditingController();
  String _erro = "";

  void _login() {
    bool sucesso = AuthService.login(_passwordController.text.trim());

    if (sucesso) {
      widget.onSuccess();
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
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "Senha",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _login,
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
