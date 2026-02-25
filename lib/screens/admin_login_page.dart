import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AdminLoginPage extends StatefulWidget {
  final VoidCallback onSuccess;
  const AdminLoginPage({super.key, required this.onSuccess});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final TextEditingController _controller = TextEditingController();
  int tentativas = 0;
  bool bloqueado = false;
  String? erro;

  void _login() {
    if (bloqueado) return;

    if (AuthService.validate(_controller.text)) {
      widget.onSuccess();
    } else {
      tentativas++;
      setState(() => erro = "Senha incorreta");

      if (tentativas >= 3) {
        bloqueado = true;
        setState(() => erro = "Bloqueado por 30 segundos");

        Future.delayed(const Duration(seconds: 30), () {
          tentativas = 0;
          bloqueado = false;
          setState(() => erro = null);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Área Administrativa"),
            const SizedBox(height: 15),
            TextField(
              controller: _controller,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Senha",
                errorText: erro,
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: bloqueado ? null : _login,
              child: const Text("Entrar"),
            )
          ],
        ),
      ),
    );
  }
}
