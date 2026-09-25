import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';

class MesquitaRegistoException implements Exception {
  final String mensagem;
  MesquitaRegistoException(this.mensagem);

  @override
  String toString() => mensagem;
}

/// Regista, lista e aprova/rejeita pedidos de mesquitas.
///
/// A identidade do requerente vem da conta Google usada para entrar
/// (ver [entrarComGoogle]) — o UID resultante do Firebase Auth é também
/// o futuro ID da mesquita.
class MesquitaRegistoService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  static DatabaseReference get _db => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://mesquita-40d71-default-rtdb.europe-west1.firebasedatabase.app/',
      ).ref();

  /// Autentica com uma conta Google — usado tanto no registo de uma nova
  /// mesquita como no login do admin de uma mesquita já aprovada.
  /// Lança [MesquitaRegistoException] se o utilizador cancelar o diálogo.
  static Future<User> entrarComGoogle() async {
    try {
      // Sem isto, depois do primeiro login o Google reutiliza em silêncio a
      // última conta — o utilizador nunca chega a ver a lista para escolher
      // (ex: admin de outra mesquita no mesmo telemóvel).
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw MesquitaRegistoException("Início de sessão com Google cancelado.");
      }

      final googleAuth = await googleUser.authentication;
      final credencial = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credencial);
      return userCredential.user!;
    } on MesquitaRegistoException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw MesquitaRegistoException("Erro ao entrar com Google (${e.code}).");
    } on PlatformException catch (e) {
      // "ApiException: 10" = DEVELOPER_ERROR: a impressão digital (SHA-1)
      // da chave que assinou esta app não está registada no Firebase, ou
      // o login Google não está activo em Authentication.
      if ('${e.message}'.contains('10:') || e.code == 'sign_in_failed') {
        throw MesquitaRegistoException(
            "O login com Google ainda não está configurado para esta versão da app. "
            "Contacte o administrador do MosqueNow.");
      }
      if (e.code == 'network_error') {
        throw MesquitaRegistoException(
            "Sem ligação à internet. Verifique a ligação e tente novamente.");
      }
      throw MesquitaRegistoException("Erro ao entrar com Google (${e.code}).");
    } catch (e) {
      throw MesquitaRegistoException(
          "Não foi possível entrar com Google. Verifique a sua ligação e tente novamente.");
    }
  }

  static Future<void> sairGoogle() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
  }

  /// Referência à mesquita administrada pelo utilizador com este UID.
  static DatabaseReference refParaMesquita(String uid) =>
      _db.child("mesquitas/$uid");

  /// "aprovado" | "pendente" | "rejeitado" | "inexistente" — usado no
  /// login do admin principal para saber se já pode gerir a mesquita.
  static Future<String> statusParaUid(String uid) async {
    final aprovada = await refParaMesquita(uid).get();
    if (aprovada.exists) return "aprovado";

    final pendente = await _db.child("mesquitas_pendentes/$uid").get();
    if (pendente.exists) {
      final dados = Map<String, dynamic>.from(pendente.value as Map);
      return dados['status']?.toString() ?? "pendente";
    }

    return "inexistente";
  }

  /// Grava o pedido em mesquitas_pendentes/{uid}. Assume que o requerente
  /// já está autenticado via [entrarComGoogle] — usa esse UID directamente
  /// (também o futuro ID da mesquita) e guarda o token FCM do dispositivo
  /// para poder notificar quando o super-admin aprovar.
  static Future<String> registar({
    required String nomeRequerente,
    required String telefoneRequerente,
    required String emailRequerente,
    required String cargo,
    required String pais,
    required String cidade,
    required String bairro,
    String? endereco,
    required String nomeMesquita,
    required String contactoMesquita,
    String? emailMesquita,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw MesquitaRegistoException(
          "Sessão Google expirada. Entre novamente com o Google.");
    }

    try {
      final uid = user.uid;
      // O token só serve para avisar da aprovação — se falhar, o registo
      // continua (antes, uma falha aqui fazia falhar o registo inteiro).
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (_) {}

      await _db.child("mesquitas_pendentes/$uid").set({
        "status": "pendente",
        "criado_em": ServerValue.timestamp,
        "fcm_token_admin": fcmToken ?? "",
        "requerente": {
          "nome": nomeRequerente.trim(),
          "telefone": telefoneRequerente.trim(),
          "email": emailRequerente.trim(),
          "cargo": cargo.trim(),
        },
        "localizacao": {
          "pais": pais.trim(),
          "cidade": cidade.trim(),
          "bairro": bairro.trim(),
          "endereco": (endereco ?? "").trim(),
        },
        "mesquita": {
          "nome": nomeMesquita.trim(),
          "contacto": contactoMesquita.trim(),
          "email": (emailMesquita ?? "").trim(),
        },
      });

      return uid;
    } catch (e) {
      throw MesquitaRegistoException(
          "Não foi possível concluir o registo. Verifique a sua ligação e tente novamente.");
    }
  }

  static Future<List<Map<String, dynamic>>> listarPendentes() async {
    return _listarPorStatus("mesquitas_pendentes", "pendente");
  }

  static Future<List<Map<String, dynamic>>> listarRejeitados() async {
    return _listarPorStatus("mesquitas_pendentes", "rejeitado");
  }

  static Future<List<Map<String, dynamic>>> _listarPorStatus(
      String no, String status) async {
    final snap = await _db.child(no).get();
    if (!snap.exists) return [];

    final data = Map<String, dynamic>.from(snap.value as Map);
    final itens = <Map<String, dynamic>>[];

    data.forEach((key, value) {
      final item = Map<String, dynamic>.from(value as Map);
      if (item['status'] == status) {
        item['id'] = key;
        itens.add(item);
      }
    });

    itens.sort((a, b) =>
        (b['criado_em'] ?? 0).compareTo(a['criado_em'] ?? 0));
    return itens;
  }

  /// Mesquitas que vieram deste fluxo de auto-registo (têm admin_uid).
  static Future<List<Map<String, dynamic>>> listarAprovadas() async {
    final snap = await _db.child("mesquitas").get();
    if (!snap.exists) return [];

    final data = Map<String, dynamic>.from(snap.value as Map);
    final itens = <Map<String, dynamic>>[];

    data.forEach((key, value) {
      final item = Map<String, dynamic>.from(value as Map);
      if (item['admin_uid'] != null) {
        item['id'] = key;
        itens.add(item);
      }
    });

    return itens;
  }

  static Future<void> aprovar(String uid, Map<String, dynamic> pedido) async {
    final requerente = Map<String, dynamic>.from(pedido['requerente'] ?? {});
    final localizacao = Map<String, dynamic>.from(pedido['localizacao'] ?? {});
    final mesquita = Map<String, dynamic>.from(pedido['mesquita'] ?? {});

    await _db.child("mesquitas/$uid").set({
      "nome": mesquita['nome'] ?? "",
      "cidade": localizacao['cidade'] ?? "",
      "pais": localizacao['pais'] ?? "",
      "bairro": localizacao['bairro'] ?? "",
      "endereco": localizacao['endereco'] ?? "",
      "contacto": mesquita['contacto'] ?? "",
      "email": mesquita['email'] ?? "",
      "status": "ativo",
      "admin_uid": uid,
      "email_admin": requerente['email'] ?? "",
      "fajr_azan": "--:--",
      "fajr_namaz": "--:--",
      "dhuhr_azan": "--:--",
      "dhuhr_namaz": "--:--",
      "asr_azan": "--:--",
      "asr_namaz": "--:--",
      "maghrib_azan": "--:--",
      "maghrib_namaz": "--:--",
      "isha_azan": "--:--",
      "isha_namaz": "--:--",
      "jummah_azan": "--:--",
      "jummah_namaz": "--:--",
      "mes_islamico": "",
      "ano_islamico": "1447",
      "jejum": "1",
      "sehri": "--:--",
      "iftar": "--:--",
      "orador_jummah": "",
      "nissab_valor": "0",
      "fcm_token_admin": pedido['fcm_token_admin'] ?? "",
    });

    // "mover": a mesquita já vive em mesquitas/{uid}, o pedido sai de pendente.
    await _db.child("mesquitas_pendentes/$uid").remove();
  }

  /// Remove de vez uma mesquita aprovada (horários, avisos, tudo). Só o
  /// super-admin o pode fazer — as regras da base de dados garantem-no.
  static Future<void> remover(String id) async {
    await _db.child("mesquitas/$id").remove();
  }

  static Future<void> rejeitar(String uid, {String? motivo}) async {
    await _db.child("mesquitas_pendentes/$uid").update({
      "status": "rejeitado",
      "motivo_rejeicao": motivo ?? "",
      "rejeitado_em": ServerValue.timestamp,
    });
  }
}
