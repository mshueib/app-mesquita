import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Contador de Tasbih (dhikr) — vive como página do PageView principal,
/// por isso não tem AppBar própria (usa a barra do topo da Início).
class TasbihPage extends StatefulWidget {
  const TasbihPage({super.key});

  @override
  State<TasbihPage> createState() => _TasbihPageState();
}

class _TasbihPageState extends State<TasbihPage> {
  int _contadorTasbih = 0;
  bool _vibracaoAtiva = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          setState(() {
            _contadorTasbih++;
          });

          if (!_vibracaoAtiva) return;

          // Vibração normal
          HapticFeedback.lightImpact();

          // Vibração especial ao atingir 100
          if (_contadorTasbih % 100 == 0) {
            await Future.delayed(const Duration(milliseconds: 50));
            HapticFeedback.heavyImpact();
          }
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0B3D2E),
                Color(0xFF145A32),
                Color(0xFF0B3D2E),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // 🔥 PADRÃO CÍRCULO SUAVE NO FUNDO
              Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withOpacity(0.2),
                      width: 4,
                    ),
                  ),
                ),
              ),

              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🔥 TOGGLE VIBRAÇÃO
                  SwitchListTile(
                    value: _vibracaoAtiva,
                    onChanged: (v) {
                      setState(() {
                        _vibracaoAtiva = v;
                      });
                    },
                    title: const Text(
                      "Vibração",
                      style: TextStyle(color: Colors.white),
                    ),
                    activeThumbColor: const Color(0xFFD4AF37),
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    "Tasbih",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 22,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 20),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Text(
                      '$_contadorTasbih',
                      key: ValueKey(_contadorTasbih),
                      style: const TextStyle(
                        fontSize: 90,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _contadorTasbih = 0;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "RESET",
                      style: TextStyle(
                        color: Color(0xFF0B3D2E),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    "Toque em qualquer parte da tela para contar",
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
