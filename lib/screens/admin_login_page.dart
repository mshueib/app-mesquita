import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AdminLoginPage extends StatefulWidget {
  final VoidCallback onSuccess;

  const AdminLoginPage({super.key, required this.onSuccess});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final TextEditingController _pinController = TextEditingController();
  String _erro = "";
  bool _mostrarPin = false;
  bool _loading = false;
  int _tentativas = 0;
  bool _bloqueado = false;

  Future<void> _login() async {
    if (_bloqueado) return;

    setState(() {
      _loading = true;
      _erro = "";
    });

    bool sucesso = await AuthService.login(_pinController.text.trim());

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

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          const Text(
            "Acesso Administrativo",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
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
                icon: Icon(
                  _mostrarPin ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() => _mostrarPin = !_mostrarPin);
                },
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Entrar",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
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
        ],
      ),
    );
  }
}
