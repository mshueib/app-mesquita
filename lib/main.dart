import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:overlay_support/overlay_support.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'services/notification_service.dart';
import 'screens/admin_login_page.dart';
import 'screens/admin_panel_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.initialize();
  runApp(const OverlaySupport.global(child: MesquitaApp()));
}

class MesquitaApp extends StatelessWidget {
  const MesquitaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF4F1EA),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _indiceAtual = 0;
  bool _isAdminAutenticado = false;
  Timer? _timer;

  String _tempoRestante = "";
  String _proximaOracaoNome = "";
  String _proximaOracaoHora = "";
  int _contadorTasbih = 0;
  bool _vibracaoAtiva = true;

  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://mesquita-40d71-default-rtdb.europe-west1.firebasedatabase.app/',
  ).ref();

  Map<String, dynamic> dados = {};

  @override
  void initState() {
    super.initState();
    _ouvirNuvem();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _calcularCountdown();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _ouvirNuvem() {
    _dbRef.onValue.listen((event) {
      final value = event.snapshot.value;
      if (value != null && value is Map) {
        setState(() {
          dados = Map<String, dynamic>.from(value);
        });
      }
    });
  }

  void _calcularCountdown() {
    if (dados.isEmpty) return;

    DateTime agora = DateTime.now();

    Map<String, String> hrs = {
      "Fajr": dados['fajr_azan'] ?? "04:30",
      "Dhuhr": dados['dhuhr_azan'] ?? "12:15",
      "Asr": dados['asr_azan'] ?? "15:45",
      "Maghrib": dados['maghrib_azan'] ?? "18:12",
      "Isha": dados['isha_azan'] ?? "19:30",
    };

    String prox = "";
    DateTime? proxHora;

    for (var n in hrs.keys) {
      List<String> p = hrs[n]!.split(':');
      DateTime dt = DateTime(
          agora.year, agora.month, agora.day, int.parse(p[0]), int.parse(p[1]));
      if (dt.isAfter(agora)) {
        prox = n;
        proxHora = dt;
        break;
      }
    }

    if (proxHora == null) {
      prox = "Fajr";
      List<String> p = hrs["Fajr"]!.split(':');
      proxHora = DateTime(agora.year, agora.month, agora.day + 1,
          int.parse(p[0]), int.parse(p[1]));
    }

    Duration diff = proxHora.difference(agora);

    setState(() {
      _proximaOracaoNome = prox;
      _proximaOracaoHora = hrs[prox]!;
      _tempoRestante =
          "${diff.inHours}h ${diff.inMinutes % 60}m ${diff.inSeconds % 60}s";
    });
  }

  @override
  Widget build(BuildContext context) {
    final paginas = [
      _paginaInicio(),
      const Center(child: Text("Avisos")),
      _paginaTasbih(),
      _isAdminAutenticado
          ? AdminPanelPage(dbRef: _dbRef, dadosAtuais: dados)
          : AdminLoginPage(
              onSuccess: () => setState(() => _isAdminAutenticado = true)),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3D2E),
        centerTitle: true,
        title: const Text(
          "Mesquita Central de Quelimane",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: paginas[_indiceAtual],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceAtual,
        onTap: (i) => setState(() => _indiceAtual = i),
        selectedItemColor: const Color(0xFF0B3D2E),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Início"),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: "Avisos"),
          BottomNavigationBarItem(icon: Icon(Icons.touch_app), label: "Tasbih"),
          BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings), label: "Admin"),
        ],
      ),
    );
  }

  Widget _paginaInicio() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _cardAvisos(),
          const SizedBox(height: 15),
          _cardProximaOracao(),
          const SizedBox(height: 15),
          _cardIslamico(),
          const SizedBox(height: 20),
          _tabelaSalat(),
        ],
      ),
    );
  }

  Widget _cardAvisos() {
    String aviso = dados['aviso_geral']?.toString() ?? "";

    if (aviso.trim().isEmpty) {
      aviso = "Sem avisos no momento";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFD27A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        aviso,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3E2F00),
        ),
      ),
    );
  }

  Widget _cardProximaOracao() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4), // MENOR
      padding:
          const EdgeInsets.symmetric(vertical: 18, horizontal: 22), // REDUZIDO
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B3D2E), Color(0xFF145A32)],
        ),
        borderRadius: BorderRadius.circular(20), // antes maior
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Próxima Oração",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            _proximaOracaoNome,
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _proximaOracaoHora,
            style: const TextStyle(
              fontSize: 35,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD4AF37),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Faltam $_tempoRestante",
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _cardIslamico() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4), // MENOR
      padding:
          const EdgeInsets.symmetric(vertical: 18, horizontal: 20), // REDUZIDO
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4AF37)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "${dados['mes_islamico'] ?? 'RAMADHAN'} ${dados['ano_islamico'] ?? '1447'}",
            style: const TextStyle(
              fontSize: 20,
              color: Color(0xFFB8860B),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _col("Dia", dados['jejum'] ?? "0"),
              _col("Sehri", dados['sehri'] ?? "--:--"),
              _col("Iftar", dados['iftar'] ?? "--:--"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _col(String l, String v) {
    return Column(
      children: [
        Text(l, style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 4),
        Text(v,
            style: const TextStyle(
                fontSize: 20, // AUMENTADO
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B3D2E)))
      ],
    );
  }

  Widget _tabelaSalat() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          // ===== TÍTULO =====
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF0B3D2E),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
            child: const Center(
              child: Text(
                "HORÁRIOS DE SALAT",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // ===== CABEÇALHO VERDE CLARO =====
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            color: const Color(0xFFE6F2ED), // 🔥 Verde claro suave
            child: Row(
              children: const [
                Expanded(
                  child: Center(
                    child: Text(
                      "Salat",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B3D2E),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      "Azan",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B3D2E),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      "Jammah",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B3D2E),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ===== LINHAS =====
          _linha("Fajr", dados['fajr_azan'] ?? "--:--",
              dados['fajr_namaz'] ?? "--:--"),
          _linha("Dhuhr", dados['dhuhr_azan'] ?? "--:--",
              dados['dhuhr_namaz'] ?? "--:--"),
          _linha("Asr", dados['asr_azan'] ?? "--:--",
              dados['asr_namaz'] ?? "--:--"),
          _linha("Maghrib", dados['maghrib_azan'] ?? "--:--",
              dados['maghrib_namaz'] ?? "--:--"),
          _linha("Isha", dados['isha_azan'] ?? "--:--",
              dados['isha_namaz'] ?? "--:--"),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _linha(String s, String a, String j, [bool h = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: Text(
                s,
                style: TextStyle(
                  fontSize: h ? 19 : 18,
                  fontWeight: h ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                a,
                style: TextStyle(
                  fontSize: h ? 19 : 18,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                j,
                style: TextStyle(
                  fontSize: h ? 19 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0B3D2E),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paginaTasbih() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        setState(() {
          _contadorTasbih++;
        });

        if (_vibracaoAtiva) {
          bool canVibrate = await Vibrate.canVibrate;

          if (canVibrate) {
            Vibrate.feedback(FeedbackType.light);
          }
        }

        // Vibração especial ao atingir 100
        if (_contadorTasbih % 100 == 0 && _vibracaoAtiva) {
          bool canVibrate = await Vibrate.canVibrate;

          if (canVibrate) {
            Vibrate.feedback(FeedbackType.heavy);
          }
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
                    color: Color(0xFFD4AF37).withOpacity(0.2),
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
                  activeColor: const Color(0xFFD4AF37),
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
    );
  }
}
