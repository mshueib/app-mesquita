import 'package:flutter/material.dart';

class ZakatPage extends StatefulWidget {
  final double nissabAdmin;

  const ZakatPage({
    super.key,
    required this.nissabAdmin,
  });

  @override
  State<ZakatPage> createState() => _ZakatPageState();
}

class _ZakatPageState extends State<ZakatPage> {
  final TextEditingController _valorController = TextEditingController();
  final TextEditingController _nissabController = TextEditingController();

  double? _resultado;
  double? _nissabPersonalizado;

  @override
  Widget build(BuildContext context) {
    double nissabFinal = _nissabPersonalizado ?? widget.nissabAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3D2E),
        title: const Text(
          "Zakat",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========================
            // NISSAB EDITÁVEL
            // ========================
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF0B3D2E)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Nissab (Pode editar para simulação)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B3D2E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nissabController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: widget.nissabAdmin.toStringAsFixed(2),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: () {
                          double valor = double.tryParse(
                                _nissabController.text.replaceAll(',', '.'),
                              ) ??
                              widget.nissabAdmin;

                          setState(() {
                            _nissabPersonalizado = valor;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Valor actual: ${nissabFinal.toStringAsFixed(2)} MZN",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "Calculadora de Zakat",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B3D2E),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: _valorController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: "Valor total (MZN)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                double valor = double.tryParse(
                      _valorController.text.replaceAll(',', '.'),
                    ) ??
                    0.0;

                setState(() {
                  _resultado = valor * 0.025;
                });
              },
              child: const Text(
                "Calcular",
                style: TextStyle(
                  color: Color(0xFF0B3D2E),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 30),

            if (_resultado != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Zakat a pagar: ${_resultado!.toStringAsFixed(2)} MZN",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B3D2E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    (_valorController.text.isNotEmpty &&
                            (double.tryParse(_valorController.text
                                        .replaceAll(',', '.')) ??
                                    0) >=
                                nissabFinal)
                        ? "✔ Você atingiu o Nissab"
                        : "⚠ Valor abaixo do Nissab",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: (double.tryParse(_valorController.text
                                      .replaceAll(',', '.')) ??
                                  0) >=
                              nissabFinal
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
