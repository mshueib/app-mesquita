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
    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    Position position = await Geolocator.getCurrentPosition();

    _qiblaDirection = _calculateQibla(
      position.latitude,
      position.longitude,
    );
  }

  void _startCompass() {
    _compassSub = magnetometerEvents.listen((event) {
      double heading = atan2(-event.x, event.y);
      heading = heading * (180 / pi);
      heading = (heading + 360) % 360;

      setState(() {
        _heading = heading;

        double difference = (_heading - _qiblaDirection + 540) % 360 - 180;

        bool isAligned = difference.abs() < 3;

        if (isAligned && !_aligned) {
          _aligned = true;
          HapticFeedback.mediumImpact();
        }

        if (!isAligned) {
          _aligned = false;
        }
      });
    });
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
    double difference = (_qiblaDirection - _heading + 540) % 360 - 180;

    return Scaffold(
      backgroundColor: const Color(0xFF0B3D2E),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            Text(
              _aligned ? "Alinhado com a Qibla" : "Ajuste o dispositivo",
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

                      // Kaaba fixa no topo
                      const Positioned(
                        top: 20,
                        child: Icon(
                          Icons.mosque,
                          size: 35,
                          color: Colors.white,
                        ),
                      ),

                      // Seta gira corretamente
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
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
