import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:overlay_support/overlay_support.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'package:flutter/services.dart';
import 'services/notification_service.dart';
import 'screens/admin_login_page.dart';
import 'screens/admin_panel_page.dart';
import 'models/aviso_model.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'screens/qibla_page.dart';
import 'screens/zakat_page.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'services/local_storage_service.dart';
import 'dart:io';
import 'screens/developer_page.dart';

// 🔥 HANDLER BACKGROUND
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 INICIALIZAR TIMEZONE PRIMEIRO
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Africa/Maputo'));

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔥 ATIVAR CACHE OFFLINE
  FirebaseDatabase.instance.setPersistenceEnabled(true);

  // 🔥 ESSENCIAL
  await NotificationService.initialize();

  await Permission.notification.request();

  if (!await Permission.scheduleExactAlarm.isGranted) {
    final intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
    );
    await intent.launch();
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  try {
    await FirebaseMessaging.instance.requestPermission();

    await FirebaseMessaging.instance.getNotificationSettings();

    FirebaseMessaging.instance.getToken().then((token) {
      print("🔥 TOKEN: $token");
    });

    FirebaseMessaging.instance.subscribeToTopic("mesquita");
  } catch (e) {
    print("🔥 FCM offline: $e");
  }

  if (await Permission.scheduleExactAlarm.isDenied) {
    await Permission.scheduleExactAlarm.request();
  }

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
  late DatabaseReference _dbRef;
  int _indiceAtual = 0;
  bool _isAdminAutenticado = false;
  late PageController _pageController;
  bool _azanJaAgendado = false;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _avisoAnimController;
  late Animation<double> _avisoFade;
  bool _online = true;
  bool _mostrarBanner = false;
  late StreamSubscription _connectivitySubscription;
  String _tempoRestante = "";
  String _proximaOracaoNome = "";
  String _proximaOracaoHora = "";
  Map<String, dynamic> _horariosAntigos = {};
  final List<Map<String, dynamic>> _avisosAntigos = [];
  final List<String> _idsAvisosNotificados = [];
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

  Future<void> _verificarInternetInicial() async {
    final result = await Connectivity().checkConnectivity();

    bool estaOnline = result != ConnectivityResult.none;

    setState(() {
      _online = estaOnline;
      _mostrarBanner = !estaOnline; // 🔥 mostra banner se iniciar offline
    });

    if (estaOnline) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _mostrarBanner = false;
          });
        }
      });
    }
  }

  Future<bool> _temInternetReal() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _carregarCacheInicial() async {
    final dadosLocal = await LocalStorageService.carregarDados();

    if (dadosLocal != null) {
      setState(() {
        dados = dadosLocal;
      });
    }
  }

  bool _vibracaoAtiva = true;
  // 🔥 ZAKAT
  final TextEditingController _zakatController = TextEditingController();
  double? _resultadoZakat;
  final List<AvisoModel> _avisos = [];
  List<Map<String, dynamic>> _listaAvisos = [];
  /*final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://mesquita-40d71-default-rtdb.europe-west1.firebasedatabase.app/',
  ).ref("app");*/

  Map<String, dynamic> dados = {};
  // 🔔 Guardar horários antigos de Jammah
  final Map<String, String> _horariosJammahAntigos = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _carregarCacheInicial();
    _verificarInternetInicial();

    try {
      _dbRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://mesquita-40d71-default-rtdb.europe-west1.firebasedatabase.app/',
      ).ref("app");

      _dbRef.keepSynced(true); // PARA OFFLINE

      _ouvirNuvem();
    } catch (e) {
      print("🔥 Firebase indisponível (modo offline): $e");
    }
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      bool estaOnline = result != ConnectivityResult.none;

      if (estaOnline != _online) {
        setState(() {
          _online = estaOnline;
          _mostrarBanner = true;
        });

        // Se ficou online, esconder após 3 segundos
        if (estaOnline) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _mostrarBanner = false;
              });
            }
          });
        }
      }
    });
    // 🔥 TESTE SE A MENSAGEM ESTÁ A CHEGAR
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔥🔥🔥 MENSAGEM RECEBIDA");
      print("DATA: ${message.data}");
      print("NOTIFICATION: ${message.notification?.title}");
    });

    //_ouvirNuvem();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("📩 Mensagem recebida em foreground");

      if (message.notification != null) {
        NotificationService.showNotification(
          title: message.notification!.title ?? "Notificação",
          body: message.notification!.body ?? "",
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("📲 Notificação clicada");
    });

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
      _verificarMudancaDeDia();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _avisoAnimController.dispose();
    _zakatController.dispose();
    _connectivitySubscription.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _ouvirNuvem() {
    _dbRef.onValue.listen((event) {
      final value = event.snapshot.value;

      if (value == null || value is! Map) {
        print("⚠️ Nenhum dado novo - mantendo cache");
        return;
      }

      final dadosMap = Map<String, dynamic>.from(value);

      List<Map<String, dynamic>> avisosTemp = [];

      if (dadosMap['avisos'] != null && dadosMap['avisos'] is Map) {
        final avisosMap = Map<String, dynamic>.from(dadosMap['avisos']);

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
      }

      // 🔥 AQUI ESTÁ A CORREÇÃO
      _verificarNovoAviso(avisosTemp);
      // _verificarMudancaHorarios(dadosMap);
      // _verificarMudancaJammah(dadosMap);

      setState(() {
        dados = dadosMap;
        _listaAvisos = avisosTemp;
      });
      LocalStorageService.salvarDados(dadosMap);
      if (!_azanJaAgendado) {
        _azanJaAgendado = true; // 👈 PRIMEIRO define true
        _agendarTodosAzan(dadosMap);
      }
    });
  }

  Future<void> _agendarTodosAzan(Map<String, dynamic> dadosMap) async {
    if (dadosMap.isEmpty) return;

    print("🔥 A AGENDAR AZAN...");

    final horarios = {
      "Fajr": dadosMap['fajr_azan'],
      "Dhuhr": dadosMap['dhuhr_azan'],
      "Asr": dadosMap['asr_azan'],
      "Maghrib": dadosMap['maghrib_azan'],
      "Isha": dadosMap['isha_azan'],
    };

    int id = 500;

    for (var entry in horarios.entries) {
      final nome = entry.key;
      final horaStr = entry.value;

      if (horaStr == null) continue;

      final partes = horaStr.toString().split(':');
      if (partes.length != 2) continue;

      final hour = int.tryParse(partes[0]) ?? 0;
      final minute = int.tryParse(partes[1]) ?? 0;

      if (hour < 0 || hour > 23) continue;
      if (minute < 0 || minute > 59) continue;

      id++;

      print("🕌 Agendando $nome para $hour:$minute");

      await NotificationService.scheduleAzan(
        prayerName: nome,
        hour: hour,
        minute: minute,
        id: id,
      );
    }
  }

  Future<void> _verificarMudancaDeDia() async {
    if (dados.isEmpty) return;

    final agora = DateTime.now();

    // 🔥 Ler horário de Maghrib
    String maghribStr = dados['maghrib_azan'] ?? "18:00";
    List<String> partes = maghribStr.split(':');

    if (partes.length != 2) return;

    DateTime hojeMaghrib = DateTime(
      agora.year,
      agora.month,
      agora.day,
      int.parse(partes[0]),
      int.parse(partes[1]),
    );

    // 🔥 Se ainda não chegou Maghrib → não muda
    if (agora.isBefore(hojeMaghrib)) return;

    // 🔥 Data base islâmica começa após Maghrib
    DateTime dataIslamica = DateTime(agora.year, agora.month, agora.day);

    String? ultimaDataStr = dados['ultima_data_jejum'];

    if (ultimaDataStr == null || ultimaDataStr.isEmpty) {
      await _dbRef.update({
        'ultima_data_jejum': _formatarData(dataIslamica),
      });
      return;
    }

    DateTime ultimaData = DateTime.parse(ultimaDataStr);

    if (ultimaData.isBefore(dataIslamica)) {
      int diaAtual = int.tryParse(dados['jejum']?.toString() ?? "1") ?? 1;

      int novoDia = diaAtual + 1;

      if (novoDia > 30) {
        novoDia = 1;
      }

      await _dbRef.update({
        'jejum': novoDia.toString(),
        'ultima_data_jejum': _formatarData(dataIslamica),
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

  String _formatarData(DateTime data) {
    return "${data.year.toString().padLeft(4, '0')}-"
        "${data.month.toString().padLeft(2, '0')}-"
        "${data.day.toString().padLeft(2, '0')}";
  }

  String _formatarDataHora(String dataIso) {
    try {
      DateTime data = DateTime.parse(dataIso).toLocal();

      return "${data.day.toString().padLeft(2, '0')}/"
          "${data.month.toString().padLeft(2, '0')}/"
          "${data.year} "
          "${data.hour.toString().padLeft(2, '0')}:"
          "${data.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "";
    }
  }

  void _verificarMudancaHorarios(Map<String, dynamic> novosDados) {
    final chaves = {
      'fajr_azan': 'Fajr',
      'dhuhr_azan': 'Dhuhr',
      'asr_azan': 'Asr',
      'maghrib_azan': 'Maghrib',
      'isha_azan': 'Isha',
    };

    if (_horariosAntigos.isEmpty) {
      _horariosAntigos = {
        for (var chave in chaves.keys)
          chave: novosDados[chave]?.toString() ?? ""
      };
      return;
    }

    for (var chave in chaves.keys) {
      String antigo = _horariosAntigos[chave] ?? "";
      String novo = novosDados[chave]?.toString() ?? "";

      if (antigo != novo && novo.isNotEmpty) {
        NotificationService.showNotification(
          title: "🕌 Actualização de Horário",
          body: "${chaves[chave]} - Azan actualizado para $novo",
        );
      }
    }

    _horariosAntigos = {
      for (var chave in chaves.keys) chave: novosDados[chave]?.toString() ?? ""
    };
  }

  void _verificarNovoAviso(List<Map<String, dynamic>> novosAvisos) {
    for (var aviso in novosAvisos) {
      String id = aviso['id'];

      if (!_idsAvisosNotificados.contains(id)) {
        NotificationService.showNotification(
          title: "Novo Aviso",
          body: aviso['texto'] ?? "",
        );

        _idsAvisosNotificados.add(id);
      }
    }
  }

  void _calcularCountdown() {
    if (dados.isEmpty) return;

    DateTime agora = DateTime.now();

    Map<String, String> hrs = {
      "Fajr": dados['fajr_azan'] ?? "04:30",
      "Zohr": dados['dhuhr_azan'] ?? "12:15",
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

  void _verificarMudancaJammah(Map<String, dynamic> novosDados) {
    final camposJammah = {
      'fajr_namaz': 'Fajr',
      'dhuhr_namaz': 'Dhuhr',
      'asr_namaz': 'Asr',
      'maghrib_namaz': 'Maghrib',
      'isha_namaz': 'Isha',
      'jummah_namaz': 'Jummah',
    };

    for (var campo in camposJammah.keys) {
      final novoValor = novosDados[campo]?.toString() ?? "";

      if (_horariosJammahAntigos.containsKey(campo)) {
        final antigoValor = _horariosJammahAntigos[campo];

        if (antigoValor != novoValor && novoValor.isNotEmpty) {
          NotificationService.showNotification(
            title: "🕌 Actualização de Horário",
            body: "${camposJammah[campo]} - Iqamah actualizada para $novoValor",
          );
        }
      }

      _horariosJammahAntigos[campo] = novoValor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final paginas = [
      _paginaInicio(),
      _paginaAvisos(),
      _paginaTasbih(),
      ZakatPage(
        nissabAdmin:
            double.tryParse(dados['nissab_valor']?.toString() ?? "0") ?? 0,
      ),
      const QiblaPage(),
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
      const DeveloperPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3D2E),
        centerTitle: true,
        title: const Text(
          "Masjid Central de Quelimane",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          // 🔥 PAGEVIEW (SWIPE)
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _indiceAtual = index;
              });
            },
            children: paginas,
          ),

          // 🔴🟢 BANNER
          if (_mostrarBanner)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: _online ? Colors.green : Colors.red,
                child: SafeArea(
                  bottom: false,
                  child: Center(
                    child: Text(
                      _online
                          ? "🟢 Conexão restaurada"
                          : "🔴 Sem conexão à internet",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceAtual,
        onTap: (i) {
          _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        selectedItemColor: const Color(0xFF0B3D2E),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Início"),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: "Avisos"),
          BottomNavigationBarItem(icon: Icon(Icons.touch_app), label: "Tasbih"),
          BottomNavigationBarItem(
            icon: Icon(Icons.calculate),
            label: "Zakat",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: "Qibla"),
          BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings), label: "Admin"),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline),
            label: "Sobre",
          ),
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
    if (dados.isEmpty) {
      return const SizedBox(); // evita erro no primeiro carregamento
    }

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

    String tipo = aviso['tipo'] ?? 'geral';
    String texto = aviso['texto'] ?? '';

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

    return GestureDetector(
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
                  Text(
                    tipo.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: corTitulo,
                    ),
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
    List<Widget> cards = [];

    // 🕌 ORADOR JUMU'AH
    String orador = dados['orador_jummah']?.toString() ?? "";

    if (orador.trim().isNotEmpty) {
      cards.add(
        _buildAvisoBox(
          titulo: "ORADOR DE JUMMAH",
          texto: orador,
          corFundo: const Color(0xFFE3F2FD), // dourado leve premium
          corTexto: const Color(0xFF0D47A1), // dourado escuro elegante
          icone: Icons.mosque,
        ),
      );

      cards.add(const SizedBox(height: 16));
    }

    // 📢 OUTROS AVISOS
    for (var aviso in _listaAvisos) {
      Color corFundo = const Color(0xFFFFF8E1);
      Color corTitulo = const Color(0xFF0B3D2E);
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

      cards.add(
        _buildAvisoBox(
          titulo: aviso['tipo'].toString().toUpperCase(),
          texto: aviso['texto'] ?? "",
          corFundo: corFundo,
          corTexto: corTitulo,
          icone: icone,
        ),
      );

      cards.add(const SizedBox(height: 16));
    }

    if (cards.isEmpty) {
      return const Center(
        child: Text("Sem avisos disponíveis"),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: cards,
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
    return Column(
      children: [
        // ==============================
        // TABELA PRINCIPAL SALAT
        // ==============================
        Container(
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

              // ===== CABEÇALHO =====
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                color: const Color(0xFFE6F2ED),
                child: Row(
                  children: const [
                    Expanded(
                        child: Center(
                            child: Text("Salat",
                                style:
                                    TextStyle(fontWeight: FontWeight.bold)))),
                    Expanded(
                        child: Center(
                            child: Text("Azan",
                                style:
                                    TextStyle(fontWeight: FontWeight.bold)))),
                    Expanded(
                        child: Center(
                            child: Text("Iqámat",
                                style:
                                    TextStyle(fontWeight: FontWeight.bold)))),
                  ],
                ),
              ),

              _linha("Fajr", dados['fajr_azan'] ?? "--:--",
                  dados['fajr_namaz'] ?? "--:--"),
              _linha("Zohr", dados['dhuhr_azan'] ?? "--:--",
                  dados['dhuhr_namaz'] ?? "--:--"),
              _linha("Asr", dados['asr_azan'] ?? "--:--",
                  dados['asr_namaz'] ?? "--:--"),
              _linha("Maghrib", dados['maghrib_azan'] ?? "--:--",
                  dados['maghrib_namaz'] ?? "--:--"),
              _linha("Isha", dados['isha_azan'] ?? "--:--",
                  dados['isha_namaz'] ?? "--:--"),
              _linha("Jummah", dados['jummah_azan'] ?? "--:--",
                  dados['jummah_namaz'] ?? "--:--"),

              const SizedBox(height: 12),
            ],
          ),
        ),

        // ==============================
        // ÚLTIMA ATUALIZAÇÃO
        // ==============================
        if (dados['ultima_atualizacao_salat'] != null &&
            dados['ultima_atualizacao_salat'].toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.schedule, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  "Última actualização: ${_formatarDataHora(dados['ultima_atualizacao_salat'])}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

        // ==============================
        // PAINEL COMPLEMENTAR
        // ==============================
        if (dados['suhoor'] != null && dados['suhoor'].toString().isNotEmpty)
          if (dados['suhoor'] != null && dados['suhoor'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F6EC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFD4AF37),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _extraCompact(
                            Icons.nights_stay, "Suhoor", dados['suhoor']),
                        _extraCompact(
                            Icons.wb_sunny, "Nascer", dados['nascer_sol']),
                        _extraCompact(
                            Icons.brightness_high, "Ishraq", dados['ishraq']),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Zawwal",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8B6F00),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dados['zawwal'] ?? "--:--",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B6F00),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _extraCol(IconData icon, String label, String? value) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF0B3D2E)),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value ?? "--:--",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0B3D2E),
          ),
        ),
      ],
    );
  }

  Widget _extraColPremium(IconData icon, String label, String? value) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFF0B3D2E),
          size: 26,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF444444),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value ?? "--:--",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0B3D2E),
          ),
        ),
      ],
    );
  }

  Widget _extraZawwal(String? value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37).withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.schedule,
            color: Color(0xFFD4AF37),
            size: 26,
          ),
          const SizedBox(height: 6),
          const Text(
            "Zawwal",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8B6F00),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value ?? "--:--",
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B6F00),
            ),
          ),
        ],
      ),
    );
  }

  Widget _extraCompact(IconData icon, String label, String? value) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF0B3D2E),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value ?? "--:--",
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0B3D2E),
          ),
        ),
      ],
    );
  }

  Widget _linha(String nome, String azan, String iqamah) {
    bool isProxima = nome == _proximaOracaoNome;

    double largura = MediaQuery.of(context).size.width;
    bool telaPequena = largura < 360;

    return AnimatedScale(
      scale: isProxima ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 400),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isProxima
              ? const Color.fromARGB(255, 193, 170, 92).withOpacity(0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isProxima
              ? Border.all(
                  color: const Color(0xFFD4AF37),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  nome,
                  style: TextStyle(
                    fontSize: telaPequena ? 15 : 17,
                    fontWeight: isProxima ? FontWeight.bold : FontWeight.w500,
                    color: isProxima ? const Color(0xFF0B3D2E) : Colors.black87,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  azan,
                  style: TextStyle(
                    fontSize: telaPequena ? 15 : 17,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  iqamah,
                  style: TextStyle(
                    fontSize: telaPequena ? 15 : 17,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0B3D2E),
                  ),
                ),
              ),
            ),
          ],
        ),
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
