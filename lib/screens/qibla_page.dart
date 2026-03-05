import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';

class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key});

  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> {
  double _heading = 0;
  double _qiblaDirection = 0;
  bool _aligned = false;
  StreamSubscription? _compassSub;

  bool _semMagnetometro = false;
  bool _semLocalizacao = false;
  bool _carregando = true;

  static const double kaabaLat = 21.4225;
  static const double kaabaLng = 39.8262;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _startCompass();
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _semLocalizacao = true;
          _carregando = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition();

      _qiblaDirection = _calculateQibla(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return; // verificar antes de setState
      setState(() {
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _semLocalizacao = true;
        _carregando = false;
      });
    }
  }

  void _startCompass() {
    try {
      _compassSub = magnetometerEventStream().listen(
        (event) {
          double heading = atan2(-event.x, event.y);
          heading = heading * (180 / pi);
          heading = (heading + 360) % 360;

          // 🔥 Só actualiza se mudou mais de 1 grau
          if ((heading - _heading).abs() < 1.0) return;

          double difference = (_qiblaDirection - heading + 540) % 360 - 180;
          bool isAligned = difference.abs() < 3;

          if (isAligned && !_aligned) {
            HapticFeedback.mediumImpact();
          }

          setState(() {
            _heading = heading;
            _aligned = isAligned;
          });
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _semMagnetometro = true;
          });
        },
      );
    } catch (e) {
      setState(() {
        _semMagnetometro = true;
      });
    }
  }

  double _calculateQibla(double lat, double lng) {
    double dLon = _degToRad(kaabaLng - lng);
    double y = sin(dLon);
    double x = cos(_degToRad(lat)) * tan(_degToRad(kaabaLat)) -
        sin(_degToRad(lat)) * cos(dLon);
    double bearing = atan2(y, x);
    bearing = _radToDeg(bearing);
    return (bearing + 360) % 360;
  }

  double _degToRad(double deg) => deg * pi / 180;
  double _radToDeg(double rad) => rad * 180 / pi;

  @override
  Widget build(BuildContext context) {
    // 🔥 LOADING
    if (_carregando) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B3D2E),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFD4AF37),
          ),
        ),
      );
    }

    // 🔥 SEM LOCALIZAÇÃO
    if (_semLocalizacao) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B3D2E),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_off,
                  color: Color(0xFFD4AF37),
                  size: 64,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Localização não disponível",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  "Para usar a Qibla, permita o acesso à localização nas definições do dispositivo.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Geolocator.openAppSettings();
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text("Abrir Definições"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: const Color(0xFF0B3D2E),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 🔥 SEM MAGNETÓMETRO
    if (_semMagnetometro) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B3D2E),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.explore_off,
                  color: Color(0xFFD4AF37),
                  size: 64,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Bússola não disponível",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  "O seu dispositivo não possui magnetómetro.\nNão é possível determinar a direcção da Qibla automaticamente.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD4AF37)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Direcção da Qibla",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${_qiblaDirection.toStringAsFixed(1)}°",
                        style: const TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Use uma bússola física para encontrar esta direcção",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 🔥 ECRÃ NORMAL DA QIBLA
    double difference = (_qiblaDirection - _heading + 540) % 360 - 180;

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D2E),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            Text(
              _aligned ? "✅ Alinhado com a Qibla" : "Ajuste o dispositivo",
              style: TextStyle(
                color: _aligned ? Colors.greenAccent : Colors.white70,
                fontSize: 18,
              ),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 320,
                  height: 320,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFD4AF37),
                            width: 4,
                          ),
                        ),
                      ),
                      const Positioned(
                        top: 20,
                        child: Icon(
                          Icons.mosque,
                          size: 35,
                          color: Colors.white,
                        ),
                      ),
                      Transform.rotate(
                        angle: difference * pi / 180,
                        child: const Icon(
                          Icons.navigation,
                          size: 90,
                          color: Color(0xFFD4AF37),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Text(
                "Qibla: ${_qiblaDirection.toStringAsFixed(1)}°",
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
