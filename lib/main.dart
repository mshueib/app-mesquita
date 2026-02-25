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
import 'models/aviso_model.dart';

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

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _indiceAtual = 0;
  bool _isAdminAutenticado = false;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _avisoAnimController;
  late Animation<double> _avisoFade;
  String _tempoRestante = "";
  String _proximaOracaoNome = "";
  String _proximaOracaoHora = "";
  Map<String, dynamic> _horariosAntigos = {};
  List<Map<String, dynamic>> _avisosAntigos = [];
  int _contadorTasbih = 0;
  int _prioridadeAviso(String tipo) {
    switch (tipo) {
      case 'janazah':
        return 0; // 🔥 mais importante
      case 'nikah':
        return 1;
      case 'geral':
      default:
        return 2;
    }
  }

  bool _vibracaoAtiva = true;
  final List<AvisoModel> _avisos = [];
  List<Map<String, dynamic>> _listaAvisos = [];
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

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _avisoAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _avisoFade = CurvedAnimation(
      parent: _avisoAnimController,
      curve: Curves.easeOut,
    );

    _pulseController.repeat(reverse: true);

    // 🔥 UM ÚNICO TIMER
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _calcularCountdown();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _avisoAnimController.dispose();
    super.dispose();
  }

  void _ouvirNuvem() {
    _dbRef.onValue.listen((event) {
      final value = event.snapshot.value;

      if (value == null || value is! Map) return;

      final dadosMap = Map<String, dynamic>.from(value);

      List<Map<String, dynamic>> avisosTemp = [];

      if (dadosMap['avisos'] is Map) {
        final avisosMap = Map<String, dynamic>.from(dadosMap['avisos'] ?? {});

        avisosMap.forEach((key, v) {
          if (v is Map) {
            avisosTemp.add({
              'id': key,
              'tipo': v['tipo'] ?? 'geral',
              'texto': v['texto'] ?? '',
              'prazo': v['prazo'] ?? '',
            });
          }
        });

        avisosTemp = avisosTemp.reversed.toList();
        avisosTemp.sort((a, b) =>
            _prioridadeAviso(a['tipo']) - _prioridadeAviso(b['tipo']));
      }
      _verificarMudancaHorarios(dadosMap);
      _verificarNovoAviso(avisosTemp);

      if (!mounted) return;

      setState(() {
        dados = dadosMap;
        _listaAvisos = avisosTemp;
      });

      // 🔥 Só animar se houver avisos
      if (_listaAvisos.isNotEmpty) {
        _avisoAnimController.forward(from: 0);
      }
    });
  }

  Future<void> _verificarMudancaDeDia() async {
    if (dados.isEmpty) return;

    final hoje = DateTime.now();
    final hojeLimpo = DateTime(hoje.year, hoje.month, hoje.day);

    String? ultimaDataStr = dados['ultima_data_jejum'];

    if (ultimaDataStr == null || ultimaDataStr.isEmpty) {
      await _dbRef.update({
        'ultima_data_jejum': "${hoje.year.toString().padLeft(4, '0')}-"
            "${hoje.month.toString().padLeft(2, '0')}-"
            "${hoje.day.toString().padLeft(2, '0')}",
      });
      return;
    }

    DateTime ultimaData = DateTime.parse(ultimaDataStr);
    DateTime ultimaLimpa =
        DateTime(ultimaData.year, ultimaData.month, ultimaData.day);

    int diferencaDias = hojeLimpo.difference(ultimaLimpa).inDays;

    if (diferencaDias > 0) {
      int diaAtual = int.tryParse(dados['jejum']?.toString() ?? "1") ?? 1;

      int novoDia = diaAtual;

      for (int i = 0; i < diferencaDias; i++) {
        novoDia = novoDia < 30 ? novoDia + 1 : 1;
      }

      await _dbRef.update({
        'jejum': novoDia.toString(),
        'ultima_data_jejum': "${hoje.year.toString().padLeft(4, '0')}-"
            "${hoje.month.toString().padLeft(2, '0')}-"
            "${hoje.day.toString().padLeft(2, '0')}",
      });
    }
  }

  bool _avisoExpirado(String? prazo) {
    if (prazo == null || prazo.isEmpty) return false;

    try {
      DateTime dataPrazo = DateTime.parse(prazo);
      DateTime hoje = DateTime.now();

      DateTime hojeLimpo = DateTime(hoje.year, hoje.month, hoje.day);
      DateTime prazoLimpo =
          DateTime(dataPrazo.year, dataPrazo.month, dataPrazo.day);

      return hojeLimpo.isAfter(prazoLimpo);
    } catch (e) {
      return false;
    }
  }

  void _verificarMudancaHorarios(Map<String, dynamic> novosDados) {
    final chaves = [
      'fajr_azan',
      'dhuhr_azan',
      'asr_azan',
      'maghrib_azan',
      'isha_azan'
    ];

    for (var chave in chaves) {
      if (_horariosAntigos[chave] != null &&
          _horariosAntigos[chave] != novosDados[chave]) {
        NotificationService.showNotification(
          title: "Horário Atualizado",
          body:
              "Novo horário de ${chave.replaceAll('_azan', '')}: ${novosDados[chave]}",
        );
      }
    }

    _horariosAntigos = {for (var chave in chaves) chave: novosDados[chave]};
  }

  void _verificarNovoAviso(List<Map<String, dynamic>> novosAvisos) {
    if (_avisosAntigos.isEmpty) {
      _avisosAntigos = novosAvisos;
      return;
    }

    if (novosAvisos.length > _avisosAntigos.length) {
      final novo = novosAvisos.first;

      NotificationService.showNotification(
        title: "Novo Aviso",
        body: "${novo['tipo'].toString().toUpperCase()}: ${novo['texto']}",
      );
    }

    _avisosAntigos = novosAvisos;
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
      _paginaAvisos(),
      _paginaTasbih(),
      _isAdminAutenticado
          ? AdminPanelPage(
              dbRef: _dbRef,
              dadosAtuais: dados,
              onLogout: () {
                setState(() {
                  _isAdminAutenticado = false;
                  _indiceAtual = 0;
                });
              },
            )
          : AdminLoginPage(
              onSuccess: () => setState(() => _isAdminAutenticado = true),
            ),
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
          _cardAvisosPrincipal(),
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

  Widget _cardAvisosPrincipal() {
    if (_listaAvisos.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            "Sem avisos no momento",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Color(0xFF0B3D2E),
            ),
          ),
        ),
      );
    }

    final aviso = _listaAvisos.first;

    String tipo = (aviso['tipo'] ?? 'geral').toString();
    String texto = (aviso['texto'] ?? '').toString();

    Color corFundo = const Color(0xFFEFD27A);
    Color corTitulo = const Color(0xFF3E2F00);
    IconData icone = Icons.info_outline;

    if (tipo == 'janazah') {
      corFundo = const Color(0xFFFFEBEE);
      corTitulo = const Color(0xFFB71C1C);
      icone = Icons.campaign;
    } else if (tipo == 'nikah') {
      corFundo = const Color(0xFFDFF5E1);
      corTitulo = const Color(0xFF0B3D2E);
      icone = Icons.favorite;
    }

    final totalExtras = _listaAvisos.length - 1;

    return FadeTransition(
      opacity: _avisoFade,
      child: GestureDetector(
        onTap: () => setState(() => _indiceAtual = 1),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: corFundo,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Icon(icone, color: corTitulo, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          tipo.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: corTitulo,
                          ),
                        ),
                        if (totalExtras > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: corTitulo.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "+$totalExtras",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: corTitulo,
                              ),
                            ),
                          ),
                        ]
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      texto,
                      style: const TextStyle(fontSize: 15, height: 1.4),
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

  Widget _buildAvisoBox({
    required String titulo,
    required String texto,
    required Color corFundo,
    required Color corTexto,
    required IconData icone,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: corTexto, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (titulo.isNotEmpty)
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: corTexto,
                    ),
                  ),
                if (titulo.isNotEmpty) const SizedBox(height: 4),
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: corTexto,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paginaAvisos() {
    if (_listaAvisos.isEmpty) {
      return const Center(
        child: Text(
          "Sem avisos disponíveis",
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF0B3D2E),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _listaAvisos.length,
      itemBuilder: (context, index) {
        final aviso = _listaAvisos[index];

        Color corFundo = const Color.fromARGB(255, 242, 242, 43);
        Color corTitulo = const Color.fromARGB(255, 10, 10, 0);
        IconData icone = Icons.info_outline;

        if (aviso['tipo'] == 'janazah') {
          corFundo = const Color(0xFFFFEBEE);
          corTitulo = const Color(0xFFB71C1C);
          icone = Icons.campaign;
        } else if (aviso['tipo'] == 'nikah') {
          corFundo = const Color(0xFFDFF5E1);
          corTitulo = const Color(0xFF0B3D2E);
          icone = Icons.favorite;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: corFundo,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icone,
                color: corTitulo,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      aviso['tipo'].toString().toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: corTitulo,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      aviso['texto'] ?? "",
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if ((aviso['prazo'] ?? "").toString().isNotEmpty)
                      Text(
                        "Expira: ${aviso['prazo']}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _cardProximaOracao() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0B3D2E),
              Color(0xFF1E6B3C),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            const Text(
              "Próxima Oração",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 6),
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
                color: Color(0xFFD4AF37),
                fontSize: 44,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Faltam $_tempoRestante",
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
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
    );
  }
}
