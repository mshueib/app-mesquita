import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:overlay_support/overlay_support.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'services/local_storage_service.dart';
import 'screens/audio_page.dart';
import 'screens/mesquitas_page.dart';
import 'screens/settings_page.dart';
import 'screens/mais_page.dart';
import 'screens/tasbih_page.dart';
import 'screens/zakat_page.dart';
import 'screens/qibla_page.dart';
import 'screens/islamico_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// 🔥 HANDLER BACKGROUND
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // As mensagens da Cloud Function trazem "notification": com a app em
  // segundo plano o Android já a mostra sozinho — mostrá-la aqui outra
  // vez duplicava todas as notificações. Só mostramos se vier sem ela.
  if (message.notification == null) {
    final corpo = message.data['body']?.toString() ?? "";
    if (corpo.trim().isNotEmpty) {
      await NotificationService.showNotification(
        title: message.data['title']?.toString() ?? "🕌 MosqueNow",
        body: corpo,
      );
    }
  }

  // Avisos não mexem nos horários.
  if (message.data['tipo'] == "aviso") return;

  final ativoAzan = await LocalStorageService.alarmeAzanAtivo();
  if (!ativoAzan) return;

  // Só reagenda se a mensagem for da mesquita cujos horários estão
  // agendados (a seleccionada, e só se for favorita) — o tópico vem em
  // message.from como "/topics/mesquita_<id>".
  final selecionada = await LocalStorageService.carregarMesquitaSelecionada() ??
      "mesquita_quelimane";
  final favoritos = await LocalStorageService.carregarFavoritos();
  if (!favoritos.contains(selecionada)) return;
  final origem = message.from ?? "";
  if (origem.startsWith("/topics/mesquita_") &&
      origem != "/topics/mesquita_$selecionada") {
    return;
  }

  final snapshot =
      await FirebaseDatabase.instance.ref("mesquitas/$selecionada").get();
  if (!snapshot.exists || snapshot.value is! Map) return;

  final dadosAtualizados = Map<String, dynamic>.from(snapshot.value as Map);

  await NotificationService.cancelarAzan();

  final tocarSom = await LocalStorageService.tocarSomAzanAtivo();

  for (var entry in {
    "Fajr": dadosAtualizados['fajr_azan'],
    "Dhuhr": dadosAtualizados['dhuhr_azan'],
    "Asr": dadosAtualizados['asr_azan'],
    "Maghrib": dadosAtualizados['maghrib_azan'],
    "Isha": dadosAtualizados['isha_azan'],
  }.entries) {
    final partes = entry.value?.toString().split(':') ?? const [];
    if (partes.length != 2) continue;
    final hora = int.tryParse(partes[0]);
    final minuto = int.tryParse(partes[1]);
    if (hora == null || minuto == null) continue;

    await NotificationService.scheduleAzan(
      prayerName: entry.key,
      hour: hora,
      minute: minuto,
      id: NotificationService.azanIds[entry.key]!,
      tocarSom: tocarSom,
    );
  }
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

  runApp(const OverlaySupport.global(child: MesquitaApp()));

  // Depois do runApp: antes, a app ficava em ecrã branco à espera das
  // janelas de permissão (e da rede, no pedido do FCM) antes de mostrar
  // qualquer coisa.
  _pedirPermissoes();
}

Future<void> _pedirPermissoes() async {
  await Permission.notification.request();

  // No Android 12, pedir esta permissão abre as Definições do sistema —
  // fazê-lo em cada arranque, se o utilizador recusou, era irritante.
  // Pede-se uma única vez (no Android 13+ já vem concedida pelo
  // USE_EXACT_ALARM e isto não mostra nada).
  if (await Permission.scheduleExactAlarm.isDenied &&
      !await LocalStorageService.pedidoAlarmeExactoFeito()) {
    await LocalStorageService.setPedidoAlarmeExactoFeito();
    await Permission.scheduleExactAlarm.request();
  }

  try {
    // Notificações são por mesquita (tópico FCM por favorita) — só
    // chegam a quem tem essa mesquita marcada como favorita.
    await FirebaseMessaging.instance.requestPermission();
  } catch (e) {
    print("🔥 FCM offline: $e");
  }
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
      // Evita que o conteúdo fique escondido atrás dos botões de navegação
      // do sistema (ex: barra de 3 botões do Samsung) em todos os ecrãs.
      builder: (context, child) => SafeArea(
        top: false,
        bottom: true,
        child: child ?? const SizedBox(),
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
  static const String _mesquitaPadrao = "mesquita_quelimane";
  static const String _urlBaseDados =
      'https://mesquita-40d71-default-rtdb.europe-west1.firebasedatabase.app/';

  static DatabaseReference _refMesquita(String id) =>
      FirebaseDatabase.instanceFor(
              app: Firebase.app(), databaseURL: _urlBaseDados)
          .ref("mesquitas/$id");

  String? _mesquitaSelecionada;

  StreamSubscription? _dbSub;
  late DatabaseReference _dbRef;
  int _indiceAtual = 0;
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

  String _proximaOracaoNome = "";

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

  Future<void> _reagendarAzanSeNecessario() async {
    try {
      final ativoAzan = await LocalStorageService.alarmeAzanAtivo();
      if (!ativoAzan) return;

      // 🔥 SÓ REAGENDA SE TIVER DADOS
      if (dados.isEmpty) {
        // Tenta carregar do Firebase
        final snapshot = await _dbRef.get();
        if (!snapshot.exists || snapshot.value is! Map) return;
        final dadosFirebase = Map<String, dynamic>.from(snapshot.value as Map);

        await NotificationService.cancelarAzan();
        await _agendarTodosAzan(dadosFirebase);
        _horariosAzanAnteriores = _horasAzan(dadosFirebase);
        return;
      }

      // 🔥 SE JÁ TEM DADOS EM CACHE, USA OS DADOS ACTUAIS
      await NotificationService.cancelarAzan();
      await _agendarTodosAzan(dados);
      // Evita que a primeira leitura da base de dados volte a agendar
      // exactamente os mesmos horários.
      _horariosAzanAnteriores = _horasAzan(dados);
    } catch (e) {
      print("❌ Erro ao reagendar azan: $e");
    }
  }

  List<Map<String, dynamic>> _listaAvisos = [];
  /*final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://mesquita-40d71-default-rtdb.europe-west1.firebasedatabase.app/',
  ).ref("app");*/

  Map<String, dynamic> dados = {};

  List<String> _favoritos = [];

  // O agendamento do Azan depende dos favoritos — sem esperar por isto,
  // o reagendamento ao abrir a app via a lista ainda vazia e cancelava
  // todos os alarmes.
  late final Future<void> _favoritosCarregados;

  Future<void> _carregarFavoritos() async {
    var favs = await LocalStorageService.carregarFavoritos();

    // 🔥 MIGRAÇÃO — utilizadores que já usavam a app antes dos favoritos
    // por mesquita não podem deixar de receber notificações sem agir.
    if (favs.isEmpty && !await LocalStorageService.migracaoFavoritosFeita()) {
      favs = ["mesquita_quelimane"];
      await LocalStorageService.salvarFavoritos(favs);
      await LocalStorageService.setMigracaoFavoritosFeita();
    }

    setState(() {
      _favoritos = favs;
    });

    // Abre na última mesquita escolhida; senão na primeira favorita.
    _mesquitaSelecionada =
        await LocalStorageService.carregarMesquitaSelecionada() ??
            (_favoritos.isNotEmpty ? _favoritos.first : _mesquitaPadrao);

    // Reconfirma as subscrições FCM em cada arranque (subscribeToTopic
    // é idempotente e não sobrevive garantidamente a reinstalações).
    for (final id in _favoritos) {
      NotificationService.subscreverMesquita(id);
    }
  }

  void _abrirDaNotificacao(RemoteMessage message) {
    if (message.data['tipo'] != "aviso") return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(1); // separador "Avisos"
      }
    });
  }

  /// Passa a mostrar outra mesquita. A escolha fica guardada (a app volta
  /// a abrir nela) e os alarmes de Azan são reagendados pelo
  /// [_ouvirNuvem] assim que chegam os dados — incluindo quando a
  /// mesquita ainda não tem dados, sem rebentar.
  Future<void> _mudarMesquita(String id) async {
    setState(() {
      _mesquitaSelecionada = id;
      _dbRef = _refMesquita(id);
      dados = {};
      _listaAvisos = [];
    });
    // Força a "primeira carga" em _verificarEReagendarAzan.
    _horariosAzanAnteriores = {};
    await LocalStorageService.salvarMesquitaSelecionada(id);
    try {
      _dbRef.keepSynced(true);
    } catch (_) {}
    _ouvirNuvem();
  }

  Future<void> _toggleFavorito(String id) async {
    if (_favoritos.contains(id)) {
      _favoritos.remove(id);
      await NotificationService.dessubscreverMesquita(id);
    } else {
      _favoritos.add(id);
      await NotificationService.subscreverMesquita(id);
    }

    await LocalStorageService.salvarFavoritos(_favoritos);

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // 🔥 VERIFICAÇÃO DE VERSÃO OBRIGATÓRIA — PRIMEIRO DE TUDO
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _verificarVersaoMinima();
    });
    _mesquitaSelecionada = _mesquitaPadrao;
    // Referência provisória só para o primeiro build — a mesquita
    // verdadeira (última escolhida) só se sabe depois de ler as
    // preferências, e só aí começamos a ouvir a base de dados.
    _dbRef = _refMesquita(_mesquitaPadrao);
    _pageController = PageController();
    _carregarCacheInicial();
    _verificarInternetInicial();

    _favoritosCarregados = _carregarFavoritos();
    _favoritosCarregados.then((_) async {
      if (!mounted) return;
      setState(() => _dbRef = _refMesquita(_mesquitaSelecionada!));
      try {
        _dbRef.keepSynced(true); // PARA OFFLINE
        _ouvirNuvem();
        await _reagendarAzanSeNecessario();
      } catch (e) {
        print("🔥 Firebase indisponível (modo offline): $e");
      }
    });
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
        // FCM de aviso — só mostra notificação (se o utilizador as quiser)
        if (!await LocalStorageService.notificacoesAvisosAtivos()) return;
        final corpoAviso = message.notification?.body ?? message.data['body'];
        if (corpoAviso == null || corpoAviso.trim().isEmpty) return;
        await NotificationService.showNotification(
          title: message.notification?.title ??
              message.data['title'] ??
              "📢 Novo Aviso",
          body: corpoAviso,
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
    // Tocar numa notificação de aviso abre directamente o separador
    // Avisos — com a app em segundo plano ou fechada.
    FirebaseMessaging.onMessageOpenedApp.listen(_abrirDaNotificacao);
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _abrirDaNotificacao(message);
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
  }

  @override
  void dispose() {
    _timer?.cancel();
    //_pulseController.dispose();
    //_avisoAnimController.dispose();
    _dbSub?.cancel();
    _connectivitySubscription.cancel();
    _pageController.dispose();
    _rodapeScrollController.dispose();
    super.dispose();
  }

  void _ouvirNuvem() {
    _dbSub?.cancel();
    _dbSub = _dbRef.onValue.listen((event) {
      final value = event.snapshot.value;

      if (value == null || value is! Map) {
        // A mesquita seleccionada deixou de existir (ex: removida pelo
        // super-admin) — volta à mesquita padrão em vez de ficar com o
        // ecrã inicial vazio.
        if (value == null && _mesquitaSelecionada != _mesquitaPadrao) {
          _mudarMesquita(_mesquitaPadrao);
        }
        return;
      }

      final dadosMap = Map<String, dynamic>.from(value);

      List<Map<String, dynamic>> avisosTemp = [];

      if (dadosMap['avisos'] != null && dadosMap['avisos'] is Map) {
        final avisosMap = Map<String, dynamic>.from(dadosMap['avisos']);

        // Avisos cujo prazo ("yyyy-MM-dd") já passou deixam de aparecer —
        // continuam visíveis durante o próprio dia do prazo. Sem prazo,
        // ficam até o admin os apagar.
        final agora = DateTime.now();
        final hoje = "${agora.year.toString().padLeft(4, '0')}-"
            "${agora.month.toString().padLeft(2, '0')}-"
            "${agora.day.toString().padLeft(2, '0')}";

        avisosMap.forEach((key, v) {
          final prazo = v is Map ? (v['prazo']?.toString() ?? '') : '';
          final expirado = prazo.isNotEmpty && prazo.compareTo(hoje) < 0;
          if (v is Map && !expirado) {
            avisosTemp.add({
              'id': key,
              'tipo': v['tipo'] ?? 'geral',
              'texto': v['texto'] ?? '',
              'prazo': v['prazo'] ?? '',
            });
          }
        });
        //ordenacao de avisos
        avisosTemp.sort((a, b) =>
            _prioridadeAviso(a['tipo']).compareTo(_prioridadeAviso(b['tipo'])));
      }
// ifatr e suhoor
      if (dadosMap['maghrib_azan'] != null) {
        dadosMap['iftar'] = dadosMap['maghrib_azan'];
      }
      if (dadosMap['sehri'] != null) {
        dadosMap['suhoor'] = dadosMap['sehri'];
      }
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

  Future<void> _verificarVersaoMinima() async {
    try {
      final snapshot =
          await FirebaseDatabase.instance.ref("app/versao_minima").get();

      final versaoMinima = snapshot.value?.toString() ?? "1.0.0";
      final packageInfo = await PackageInfo.fromPlatform();
      final versaoAtual = packageInfo.version;

      // Compara versões ex: "1.0.1" < "1.0.2"
      if (_compararVersoes(versaoAtual, versaoMinima) < 0) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => PopScope(
            canPop: false, // impede botão "back"
            child: AlertDialog(
              title: const Text("Actualização obrigatória"),
              content: const Text(
                "Uma nova versão está disponível. "
                "Por favor actualiza o app para continuar.",
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => launchUrl(
                    Uri.parse(
                      "https://play.google.com/store/apps/details?id=com.mosque.now",
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B3D2E),
                  ),
                  child: const Text(
                    "Actualizar agora",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      print("⚠️ Erro ao verificar versão: $e");
      // Se falhar (offline), deixa passar — não bloqueia o utilizador
    }
  }

// Compara "1.0.1" com "1.0.2" → retorna negativo se a < b
  // Aceita sufixo "+build" (ex: "1.0.2+4"), que é ignorado na comparação.
  int _compararVersoes(String a, String b) {
    final pa = a.split('+').first.split('.').map(int.parse).toList();
    final pb = b.split('+').first.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      final diff = (pa.elementAtOrNull(i) ?? 0) - (pb.elementAtOrNull(i) ?? 0);
      if (diff != 0) return diff;
    }
    return 0;
  }

  Future<void> _agendarTodosAzan(Map<String, dynamic> dadosMap) async {
    if (dadosMap.isEmpty) return;
    final ativoAzan = await LocalStorageService.alarmeAzanAtivo();
    if (!ativoAzan) return;

    // Alarme de azan só toca para mesquitas marcadas como favoritas —
    // mesmo comportamento que os avisos/alterações de horário já têm
    // via subscrição a tópico em _toggleFavorito.
    await _favoritosCarregados;
    if (_mesquitaSelecionada == null ||
        !_favoritos.contains(_mesquitaSelecionada)) {
      await NotificationService.cancelarAzan();
      return;
    }
    print("🔥 A AGENDAR AZAN...");

    final tocarSom = await LocalStorageService.tocarSomAzanAtivo();

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
        tocarSom: tocarSom,
      );
    }
  }

  Future<void> _agendarTodosAzanSilencioso(
      Map<String, dynamic> dadosMap) async {
    if (dadosMap.isEmpty) return;

    // VERIFICAÇÃO
    final ativoAzan = await LocalStorageService.alarmeAzanAtivo();
    if (!ativoAzan) return;

    // Alarme de azan só toca para mesquitas marcadas como favoritas.
    await _favoritosCarregados;
    if (_mesquitaSelecionada == null ||
        !_favoritos.contains(_mesquitaSelecionada)) {
      await NotificationService.cancelarAzan();
      return;
    }

    final tocarSom = await LocalStorageService.tocarSomAzanAtivo();

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

      if (horaStr == null || horaStr.isEmpty || !horaStr.contains(':')) {
        continue;
      }

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
        tocarSom: tocarSom,
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

  /// Só as horas de Azan contam — são as únicas que geram alarmes.
  static Map<String, String> _horasAzan(Map<String, dynamic> dadosMap) => {
        for (final chave in const [
          'fajr_azan',
          'dhuhr_azan',
          'asr_azan',
          'maghrib_azan',
          'isha_azan',
        ])
          chave: dadosMap[chave]?.toString() ?? "",
      };

  /// Reagenda os alarmes só quando as horas de Azan mudam de facto. Cada
  /// actualização da mesquita (avisos, Iqamah, mês islâmico...) dispara
  /// este listener — antes, ao abrir a app, os alarmes eram agendados duas
  /// vezes seguidas (cache + primeira leitura da base de dados).
  Future<void> _verificarEReagendarAzan(Map<String, dynamic> dadosMap) async {
    final novas = _horasAzan(dadosMap);
    if (novas.values.every((v) => v.isEmpty)) return;
    if (mapEquals(novas, _horariosAzanAnteriores)) return;

    _horariosAzanAnteriores = novas;
    await NotificationService.cancelarAzan();
    await _agendarTodosAzan(dadosMap);
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

  static const List<_SecaoMenu> _secoes = [
    _SecaoMenu("Início", Icons.home),
    _SecaoMenu("Avisos", Icons.info),
    _SecaoMenu("Áudio", Icons.radio),
    _SecaoMenu("Tasbih", Icons.touch_app),
    _SecaoMenu("Zakat", Icons.calculate),
    _SecaoMenu("Qibla", Icons.explore),
    _SecaoMenu("Islâmico", Icons.menu_book),
    _SecaoMenu("Mais", Icons.apps),
  ];

  final List<GlobalKey> _chavesRodape =
      List.generate(_secoes.length, (_) => GlobalKey());
  final ScrollController _rodapeScrollController = ScrollController();

  void _irParaSecao(int indice) {
    _pageController.animateToPage(
      indice,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _centralizarItemRodape(int indice) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _chavesRodape[indice].currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    });
  }

  Widget _rodapeSecoes() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: ListView.builder(
            controller: _rodapeScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            itemCount: _secoes.length,
            itemBuilder: (context, i) {
              final selecionado = i == _indiceAtual;
              return Padding(
                key: _chavesRodape[i],
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: GestureDetector(
                  onTap: () => _irParaSecao(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selecionado
                          ? const Color(0xFF0B3D2E)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _secoes[i].icone,
                          color: selecionado
                              ? Colors.white
                              : const Color(0xFF0B3D2E),
                          size: 22,
                        ),
                        if (selecionado) ...[
                          const SizedBox(width: 6),
                          Text(
                            _secoes[i].titulo,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> paginas = [
      _paginaInicio(),
      _paginaAvisos(),
      const AudioPage(),
      const TasbihPage(),
      ZakatPage(
        nissabAdmin:
            double.tryParse(dados['nissab_valor']?.toString() ?? "0") ?? 0,
      ),
      const QiblaPage(),
      const IslamicoPage(),
      MaisPage(dbRef: _dbRef, dados: dados),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3D2E),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.home, color: Colors.white),
          tooltip: "Início",
          onPressed: () {
            _pageController.animateToPage(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
        ),
        // Nome da mesquita seleccionada (campo "nome" na base de dados).
        title: Text(
          dados['nome']?.toString() ?? "MosqueNow",
          style: const TextStyle(
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
                        onSelecionar: _mudarMesquita,
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
                onTap: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()));
                  // As preferências de Azan (activar/som) só cancelam os
                  // alarmes agendados — sem isto, ficam cancelados até o
                  // utilizador reiniciar a app.
                  await _reagendarAzanSeNecessario();
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
              _centralizarItemRodape(index);
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
      bottomNavigationBar: _rodapeSecoes(),
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
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.nights_stay, size: 18, color: Color(0xFFB8860B)),
              const SizedBox(width: 8),
              Text(
                "${dados['mes_islamico'] ?? 'RAMADHAN'} ${dados['ano_islamico'] ?? '1447'}",
                style: const TextStyle(
                  fontSize: 20,
                  color: Color(0xFFB8860B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
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
              _linha("Maghrib", dados['maghrib_azan'] ?? "--:--", "Após Azan"),
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
    // Pulsação contínua — o custo fica contido pelos RepaintBoundary no
    // build(): sem eles, cada frame redesenhava a página inicial inteira.
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

  /// "HH:MM" → hoje a essa hora; null se o valor não for uma hora válida
  /// (ex: "--:--" nas mesquitas acabadas de aprovar).
  DateTime? _horaHoje(dynamic valor, DateTime agora, {int diasAMais = 0}) {
    final partes = valor?.toString().split(':') ?? const [];
    if (partes.length != 2) return null;
    final h = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    if (h == null || m == null) return null;
    return DateTime(agora.year, agora.month, agora.day + diasAMais, h, m);
  }

  void _calcular() {
    if (widget.dados.isEmpty) return;
    final agora = DateTime.now();
    const oracoes = [
      ("Fajr", 'fajr_azan', 'fajr_namaz'),
      ("Zohr", 'dhuhr_azan', 'dhuhr_namaz'),
      ("Asr", 'asr_azan', 'asr_namaz'),
      ("Maghrib", 'maghrib_azan', 'maghrib_namaz'),
      ("Isha", 'isha_azan', 'isha_namaz'),
    ];

    String prox = "";
    DateTime? proxHora;

    for (final (nome, chaveAzan, chaveIqamah) in oracoes) {
      final azan = _horaHoje(widget.dados[chaveAzan], agora);
      if (azan == null) continue;

      // 🔥 ANTES DO AZAN
      if (agora.isBefore(azan)) {
        prox = "Azan $nome";
        proxHora = azan;
        break;
      }

      // 🔥 ENTRE AZAN E IQAMAH (o Maghrib muitas vezes não tem Iqamah)
      final iqamah = _horaHoje(widget.dados[chaveIqamah], agora);
      if (iqamah != null && agora.isBefore(iqamah)) {
        prox = "Iqamah $nome";
        proxHora = iqamah;
        break;
      }
    }

    // Depois do Isha: Fajr de amanhã.
    if (proxHora == null) {
      proxHora = _horaHoje(widget.dados['fajr_azan'], agora, diasAMais: 1);
      prox = "Azan Fajr";
    }

    if (proxHora == null) {
      // Mesquita sem horários definidos ainda.
      setState(() {
        _proximaOracaoNome = "Horários por definir";
        _proximaOracaoHora = "--:--";
        _tempoRestante = "";
      });
      _avisarMudanca("");
      return;
    }

    final diff = proxHora.difference(agora);
    setState(() {
      _proximaOracaoNome = prox;
      _proximaOracaoHora =
          "${proxHora!.hour.toString().padLeft(2, '0')}:${proxHora.minute.toString().padLeft(2, '0')}";
      _tempoRestante =
          "${diff.inHours}h ${diff.inMinutes % 60}m ${diff.inSeconds % 60}s";
    });
    _avisarMudanca(prox);
  }

  // Só avisa o ecrã principal quando a próxima oração muda — antes era a
  // cada segundo, o que reconstruía a página inicial inteira sem razão.
  String? _ultimaAvisada;

  void _avisarMudanca(String prox) {
    if (prox == _ultimaAvisada) return;
    _ultimaAvisada = prox;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onProximaOracaoChanged?.call(prox);
    });
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary por fora: a animação não obriga a redesenhar o resto
    // da página inicial. Por dentro: o conteúdo do cartão fica em cache e
    // cada frame só aplica a escala (só é redesenhado 1x por segundo,
    // quando o contador muda).
    return RepaintBoundary(
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: RepaintBoundary(
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
                if (_tempoRestante.isNotEmpty)
                  Text(
                    "Faltam $_tempoRestante",
                    style: const TextStyle(color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecaoMenu {
  final String titulo;
  final IconData icone;

  const _SecaoMenu(this.titulo, this.icone);
}
