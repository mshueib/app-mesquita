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
import 'screens/audio_page.dart';
import 'screens/mesquitas_page.dart';
import 'screens/settings_page.dart';

// 🔥 HANDLER BACKGROUND
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print("📩 Notificação recebida (background)");
  // se for aviso, só mostra — não reagenda
  final tipoMsg = message.data['tipo'] ?? "";
  if (tipoMsg == "aviso") {
    await NotificationService.showNotification(
      title: message.data['title'] ?? "📢 Novo Aviso",
      body: message.data['body'] ?? "",
    );
    return;
  }

  final dbRef = FirebaseDatabase.instance.ref("mesquitas/mesquita_quelimane");

  final snapshot = await dbRef.get();

  if (!snapshot.exists) return;

  final dadosAtualizados = Map<String, dynamic>.from(snapshot.value as Map);

  await NotificationService.cancelarAzan();

  for (var entry in {
    "Fajr": dadosAtualizados['fajr_azan'],
    "Dhuhr": dadosAtualizados['dhuhr_azan'],
    "Asr": dadosAtualizados['asr_azan'],
    "Maghrib": dadosAtualizados['maghrib_azan'],
    "Isha": dadosAtualizados['isha_azan'],
  }.entries) {
    final nome = entry.key;
    final horaStr = entry.value?.toString();

    if (horaStr == null || !horaStr.contains(":")) continue;

    final partes = horaStr.split(':');

    await NotificationService.scheduleAzan(
      prayerName: nome,
      hour: int.parse(partes[0]),
      minute: int.parse(partes[1]),
      id: NotificationService.azanIds[nome]!,
    );
  }
  final title = message.data['title'] ?? "🕌 Horário actualizado";
  final body = message.data['body'] ?? "Os horários foram actualizados";

  await NotificationService.showNotification(
    title: title,
    body: body,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // 🔥 INICIALIZAR TIMEZONE PRIMEIRO
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Africa/Maputo'));

  // 🔥 ATIVAR CACHE OFFLINE
  try {
    FirebaseDatabase.instance.setPersistenceEnabled(true);
  } catch (_) {}

  // 🔥 ESSENCIAL
  await NotificationService.initialize();

  await Permission.notification.request();

  if (!await Permission.scheduleExactAlarm.isGranted) {
    final intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
    );
    await intent.launch();
  }

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

class _HomePageState extends State<HomePage> {
  String? _mesquitaSelecionada;
  String _ultimaDataProcessada = "";
  StreamSubscription? _dbSub;
  late DatabaseReference _dbRef;
  late DatabaseReference _appRef;
  int _indiceAtual = 0;
  bool _isAdminAutenticado = false;
  late PageController _pageController;
  Map<String, String> _horariosAzanAnteriores = {};
  Timer? _timer;
  //late AnimationController _pulseController;
  //late Animation<double> _pulseAnimation;
  //late AnimationController _avisoAnimController;
  //late Animation<double> _avisoFade;
  bool _online = true;
  bool _mostrarBanner = false;
  late StreamSubscription _connectivitySubscription;
  final String _tempoRestante = "";
  String _proximaOracaoNome = "";
  final String _proximaOracaoHora = "";
  final Map<String, dynamic> _horariosAntigos = {};
  final List<Map<String, dynamic>> _avisosAntigos = [];
  List<String> _idsAvisosNotificados = [];
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

  Future<void> _carregarCacheInicial() async {
    final dadosLocal = await LocalStorageService.carregarDados();

    if (dadosLocal != null) {
      setState(() {
        dados = dadosLocal;
      });
    }
  }

  Future<void> _carregarIdsNotificados() async {
    final ids = await LocalStorageService.carregarIdsNotificados();
    setState(() {
      _idsAvisosNotificados = ids;
    });
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

  List<String> _favoritos = [];

  Future<void> _carregarFavoritos() async {
    final favs = await LocalStorageService.carregarFavoritos();

    setState(() {
      _favoritos = favs;
    });

    if (_favoritos.isNotEmpty) {
      _mesquitaSelecionada = _favoritos.first;
    }
  }

  Future<void> _toggleFavorito(String id) async {
    if (_favoritos.contains(id)) {
      _favoritos.remove(id);
    } else {
      _favoritos.add(id);
    }

    await LocalStorageService.salvarFavoritos(_favoritos);

    setState(() {});
  }

  // 🔔 Guardar horários antigos de Jammah
  final Map<String, String> _horariosJammahAntigos = {};

  @override
  void initState() {
    super.initState();
    _carregarFavoritos();
    _mesquitaSelecionada = "mesquita_quelimane";
    _pageController = PageController();
    _carregarCacheInicial();
    _carregarIdsNotificados();
    _verificarInternetInicial();

    try {
      _dbRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://mesquita-40d71-default-rtdb.europe-west1.firebasedatabase.app/',
      ).ref(_mesquitaSelecionada != null
          ? "mesquitas/$_mesquitaSelecionada"
          : "app");

      _appRef = FirebaseDatabase.instance.ref("app");

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
// ✅ LISTENER ÚNICO
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print("📩 Mensagem recebida em foreground");

      final tipoMsg = message.data['tipo'] ?? "";

      if (tipoMsg == "aviso") {
        // FCM de aviso — só mostra notificação
        await NotificationService.showNotification(
          title: message.notification?.title ?? "📢 Novo Aviso",
          body: message.notification?.body ?? "",
        );
        return;
      }

      // FCM de horário — reagenda e notifica
      await _atualizarHorariosEReagendar();

      if (message.notification != null) {
        final ativoHorarios =
            await LocalStorageService.notificacoesHorariosAtivas();
        if (!ativoHorarios) return;
        await NotificationService.showNotification(
          title: message.notification!.title ?? "🕌 Horário actualizado",
          body: message.notification!.body ?? "Os horários foram actualizados",
        );
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("📲 Notificação clicada");
    });

    /*_pulseController = AnimationController(
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
    );*/

    //_pulseController.repeat(reverse: true);

    // 🔥 UM ÚNICO TIMER
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _verificarMudancaDeDia();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    //_pulseController.dispose();
    //_avisoAnimController.dispose();
    _dbSub?.cancel();
    _connectivitySubscription.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _ouvirNuvem() {
    _dbSub?.cancel();
    _dbSub = _dbRef.onValue.listen((event) {
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
      _verificarEReagendarAzan(dadosMap);
    });
  }

  Future<void> _agendarTodosAzan(Map<String, dynamic> dadosMap) async {
    if (dadosMap.isEmpty) return;
    final ativoAzan = await LocalStorageService.alarmeAzanAtivo();
    if (!ativoAzan) return;
    print("🔥 A AGENDAR AZAN...");

    final horarios = {
      "Fajr": dadosMap['fajr_azan'],
      "Dhuhr": dadosMap['dhuhr_azan'],
      "Asr": dadosMap['asr_azan'],
      "Maghrib": dadosMap['maghrib_azan'],
      "Isha": dadosMap['isha_azan'],
    };

    for (var entry in horarios.entries) {
      final nome = entry.key;
      final horaStr = entry.value?.toString();

      print("DEBUG -> $nome = $horaStr");

      if (horaStr == null || horaStr.isEmpty || !horaStr.contains(':')) {
        print("⚠️ Horário inválido para $nome");
        continue;
      }

      final partes = horaStr.split(':');
      if (partes.length != 2) continue;

      final hour = int.tryParse(partes[0]) ?? 0;
      final minute = int.tryParse(partes[1]) ?? 0;

      if (!NotificationService.azanIds.containsKey(nome)) continue;

      print("🕌 Agendando $nome para $hour:$minute");

      await NotificationService.scheduleAzan(
        prayerName: nome,
        hour: hour,
        minute: minute,
        id: NotificationService.azanIds[nome]!,
      );
    }
  }

  Future<void> _agendarTodosAzanSilencioso(
      Map<String, dynamic> dadosMap) async {
    if (dadosMap.isEmpty) return;

    final horarios = {
      "Fajr": dadosMap['fajr_azan'],
      "Dhuhr": dadosMap['dhuhr_azan'],
      "Asr": dadosMap['asr_azan'],
      "Maghrib": dadosMap['maghrib_azan'],
      "Isha": dadosMap['isha_azan'],
    };

    for (var entry in horarios.entries) {
      final nome = entry.key;
      final horaStr = entry.value?.toString();

      if (horaStr == null || horaStr.isEmpty || !horaStr.contains(':'))
        continue;

      final partes = horaStr.split(':');
      if (partes.length != 2) continue;

      final hour = int.tryParse(partes[0]) ?? 0;
      final minute = int.tryParse(partes[1]) ?? 0;

      if (!NotificationService.azanIds.containsKey(nome)) continue;

      await NotificationService.scheduleAzan(
        prayerName: nome,
        hour: hour,
        minute: minute,
        id: NotificationService.azanIds[nome]!,
      );
    }
  }

  Future<void> _atualizarHorariosEReagendar() async {
    try {
      print("🔄 Atualizando horários via FCM...");

      final snapshot = await _dbRef.get();

      if (!snapshot.exists) return;

      final dadosAtualizados = Map<String, dynamic>.from(snapshot.value as Map);

      await NotificationService.cancelarAzan();
      await _agendarTodosAzanSilencioso(dadosAtualizados);

      setState(() {
        dados = dadosAtualizados;
      });
    } catch (e) {
      print("❌ Erro ao atualizar horários: $e");
    }
  }

  Future<void> _verificarEReagendarAzan(Map<String, dynamic> dadosMap) async {
    final novosHorarios = {
      "Fajr_azan": dadosMap['fajr_azan']?.toString() ?? "",
      "Fajr_iqamah": dadosMap['fajr_namaz']?.toString() ?? "",
      "Dhuhr_azan": dadosMap['dhuhr_azan']?.toString() ?? "",
      "Dhuhr_iqamah": dadosMap['dhuhr_namaz']?.toString() ?? "",
      "Asr_azan": dadosMap['asr_azan']?.toString() ?? "",
      "Asr_iqamah": dadosMap['asr_namaz']?.toString() ?? "",
      "Maghrib_azan": dadosMap['maghrib_azan']?.toString() ?? "",
      "Maghrib_iqamah": dadosMap['maghrib_namaz']?.toString() ?? "",
      "Isha_azan": dadosMap['isha_azan']?.toString() ?? "",
      "Isha_iqamah": dadosMap['isha_namaz']?.toString() ?? "",
    };
    // sair se nenhum horário tem valor
    // evita notificação falsa ao mudar avisos
    bool algumHorarioValido = novosHorarios.values.any((v) => v.isNotEmpty);
    if (!algumHorarioValido) return;
    bool houveAlteracao = false;
    String? oracao;
    String? tipo;
    String? novoHorario;

    for (var entry in novosHorarios.entries) {
      if (entry.value == null || entry.value.isEmpty) continue;
      if (_horariosAzanAnteriores[entry.key] != entry.value) {
        houveAlteracao = true;

        final partes = entry.key.split("_");
        oracao = partes[0];
        tipo = partes[1] == "azan" ? "Azan" : "Iqamah";
        novoHorario = entry.value;

        break;
      }
    }

    if (_horariosAzanAnteriores.isEmpty) {
      print("🚀 Primeira carga — agendar tudo");

      await NotificationService.cancelarAzan();
      await _agendarTodosAzan(dadosMap);

      _horariosAzanAnteriores = novosHorarios;
      return;
    }

    if (!houveAlteracao) return;
    // 🔥 NOVO — NOTIFICAR MUDANÇA
    /*await NotificationService.showNotification(
      title: "🕌 Horário actualizado",
      body: (oracao != null && tipo != null && novoHorario != null)
          ? "$oracao ($tipo) → $novoHorario"
          : "Os horários foram actualizados",
    );*/

    _horariosAzanAnteriores = novosHorarios;

    await NotificationService.cancelarAzan();
    await _agendarTodosAzan(dadosMap);
  }

  Future<void> _verificarMudancaDeDia() async {
    if (dados.isEmpty) return;

    final agora = DateTime.now();

    // 🔥 1. GARANTIR QUE TEMOS MAGHRIB REAL
    String? maghribStr = dados['maghrib_azan'];

    if (maghribStr == null || maghribStr.isEmpty) {
      print("⚠️ Maghrib não disponível ainda");
      return;
    }

    // 🔥 2. PARSE SEGURO
    List<String> partes = maghribStr.split(':');
    if (partes.length != 2) return;

    final hour = int.tryParse(partes[0]);
    final minute = int.tryParse(partes[1]);

    if (hour == null || minute == null) return;

    // 🔥 3. CRIAR DATA DO MAGHRIB
    DateTime hojeMaghrib = DateTime(
      agora.year,
      agora.month,
      agora.day,
      hour,
      minute,
    );

    // 🔒 AINDA NÃO CHEGOU MAGHRIB → NÃO FAZ NADA
    if (agora.isBefore(hojeMaghrib)) return;

    // 🔥 4. DATA FORMATADA
    String hojeStr = "${agora.year.toString().padLeft(4, '0')}-"
        "${agora.month.toString().padLeft(2, '0')}-"
        "${agora.day.toString().padLeft(2, '0')}";

    // 🔒 5. PROTEÇÃO LOCAL (evita múltiplas execuções)
    if (_ultimaDataProcessada == hojeStr) return;

    String? ultimaDataFirebase = dados['ultima_data_jejum'];

    if (ultimaDataFirebase == hojeStr) {
      _ultimaDataProcessada = hojeStr;
      return;
    }

    print("🌙 Atualizando dia islâmico...");

    // 🔥 7. INCREMENTAR DIA
    int diaAtual = int.tryParse(dados['jejum']?.toString() ?? "1") ?? 1;

    int novoDia = diaAtual + 1;

    if (novoDia > 30) {
      novoDia = 1;
    }

    try {
      // 🔥 8. ATUALIZAR FIREBASE
      await _dbRef.update({
        'jejum': novoDia.toString(),
        'ultima_data_jejum': hojeStr,
      });

      // 🔥 9. ATUALIZAR LOCAL
      _ultimaDataProcessada = hojeStr;

      print("✅ Dia atualizado para $novoDia");
    } catch (e) {
      print("❌ Erro ao atualizar dia: $e");
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

  void _verificarNovoAviso(List<Map<String, dynamic>> novosAvisos) async {
    bool houveNovo = false;

    for (var aviso in novosAvisos) {
      String id = aviso['id'];

      if (!_idsAvisosNotificados.contains(id)) {
        final ativoAvisos =
            await LocalStorageService.notificacoesAvisosAtivos();
        if (ativoAvisos) {
          NotificationService.showNotification(
            title: "📢 Novo Aviso",
            body: aviso['texto'] ?? "",
          );
        }
        _idsAvisosNotificados.add(id);
        houveNovo = true;
      }
    }

    // 🔥 Só guarda se houve aviso novo — evita escritas desnecessárias
    if (houveNovo) {
      await LocalStorageService.salvarIdsNotificados(_idsAvisosNotificados);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> paginas = [
      _paginaInicio(),
      _paginaAvisos(),
      const AudioPage(),
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
          "Masjid Central: Quelimane",
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  if (_mesquitaSelecionada != null) {
                    _toggleFavorito(_mesquitaSelecionada!);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    _favoritos.contains(_mesquitaSelecionada)
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber,
                    size: 22,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MesquitasPage(
                        onSelecionar: (id) async {
                          setState(() {
                            _mesquitaSelecionada = id;
                            _dbRef = FirebaseDatabase.instanceFor(
                              app: Firebase.app(),
                              databaseURL:
                                  'https://mesquita-40d71-default-rtdb.europe-west1.firebasedatabase.app/',
                            ).ref("mesquitas/$id");
                          });
                          _ouvirNuvem();
                          await NotificationService.cancelarAzan();
                          await _agendarTodosAzan(await _dbRef.get().then((e) =>
                              Map<String, dynamic>.from(e.value as Map)));
                        },
                      ),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.search, color: Colors.white, size: 22),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()));
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 4, right: 8),
                  child: Icon(Icons.settings, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // 🔥 PAGEVIEW (SWIPE)
          PageView(
            controller: _pageController,
            physics: const ClampingScrollPhysics(),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.radio),
            label: "Audio",
          ),
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
          CountdownCard(
            dados: dados,
            onProximaOracaoChanged: (nome) {
              setState(() {
                _proximaOracaoNome = nome;
              });
            },
          ),
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
      onTap: () {
        _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
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

  /*Widget _cardProximaOracao() {
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
  }*/

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
              _col("Dia", (dados['jejum'] ?? "0").toString()),
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
    String nomeLimpo = _proximaOracaoNome.split(" ").last;
    bool isProxima = nome == nomeLimpo;

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

class CountdownCard extends StatefulWidget {
  final Map<String, dynamic> dados;
  final ValueChanged<String>? onProximaOracaoChanged;

  const CountdownCard({
    super.key,
    required this.dados,
    this.onProximaOracaoChanged,
  });

  @override
  State<CountdownCard> createState() => _CountdownCardState();
}

class _CountdownCardState extends State<CountdownCard>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  final String _ultimaDataProcessada = "";
  String _tempoRestante = "";
  String _proximaOracaoNome = "";
  String _proximaOracaoHora = "";
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // ✅ DESCOMENTADO
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _calcular();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      _calcular();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose(); // ✅ DESCOMENTADO
    super.dispose();
  }

  void _calcular() {
    if (widget.dados.isEmpty) return;
    DateTime agora = DateTime.now();
    final oracoes = [
      {
        "nome": "Fajr",
        "azan": widget.dados['fajr_azan'],
        "iqamah": widget.dados['fajr_namaz']
      },
      {
        "nome": "Zohr",
        "azan": widget.dados['dhuhr_azan'],
        "iqamah": widget.dados['dhuhr_namaz']
      },
      {
        "nome": "Asr",
        "azan": widget.dados['asr_azan'],
        "iqamah": widget.dados['asr_namaz']
      },
      {
        "nome": "Maghrib",
        "azan": widget.dados['maghrib_azan'],
        "iqamah": widget.dados['maghrib_namaz']
      },
      {
        "nome": "Isha",
        "azan": widget.dados['isha_azan'],
        "iqamah": widget.dados['isha_namaz']
      },
    ];
    String prox = "";
    DateTime? proxHora;

    for (var o in oracoes) {
      final azanStr = o['azan']?.toString();
      final iqamahStr = o['iqamah']?.toString();

      if (azanStr == null || iqamahStr == null) continue;

      final azanPartes = azanStr.split(':');
      final iqamahPartes = iqamahStr.split(':');

      if (azanPartes.length != 2 || iqamahPartes.length != 2) continue;

      final azan = DateTime(
        agora.year,
        agora.month,
        agora.day,
        int.parse(azanPartes[0]),
        int.parse(azanPartes[1]),
      );

      final iqamah = DateTime(
        agora.year,
        agora.month,
        agora.day,
        int.parse(iqamahPartes[0]),
        int.parse(iqamahPartes[1]),
      );

      // 🔥 ANTES DO AZAN
      if (agora.isBefore(azan)) {
        prox = "Azan ${o['nome']}";
        proxHora = azan;
        break;
      }

      // 🔥 ENTRE AZAN E IQAMAH
      if (agora.isBefore(iqamah)) {
        prox = "Iqamah ${o['nome']}";
        proxHora = iqamah;
        break;
      }
    }
    if (proxHora == null) {
      final fajrStr = widget.dados['fajr_azan'] ?? "04:30";
      final p = fajrStr.split(':');

      prox = "Azan Fajr";
      proxHora = DateTime(
        agora.year,
        agora.month,
        agora.day + 1,
        int.parse(p[0]),
        int.parse(p[1]),
      );
    }
    Duration diff = proxHora.difference(agora);
    setState(() {
      _proximaOracaoNome = prox;
      _proximaOracaoHora =
          "${proxHora!.hour.toString().padLeft(2, '0')}:${proxHora.minute.toString().padLeft(2, '0')}";
      _tempoRestante =
          "${diff.inHours}h ${diff.inMinutes % 60}m ${diff.inSeconds % 60}s";
    });
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onProximaOracaoChanged?.call(prox);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B3D2E), Color(0xFF1E6B3C)],
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
}
