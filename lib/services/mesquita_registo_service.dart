import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class MesquitaRegistoException implements Exception {
  final String mensagem;
  MesquitaRegistoException(this.mensagem);

  @override
  String toString() => mensagem;
}

/// Regista, lista e aprova/rejeita pedidos de mesquitas.
///
/// O "username" escolhido pelo requerente não é um email real — serve
/// apenas para o Firebase Auth (que exige email+password), por isso é
/// mapeado para "username@mosquenow.app" só para efeitos de autenticação.
/// A senha nunca é gravada na Realtime Database — só o UID resultante.
class MesquitaRegistoService {
  static const _dominioAuth = "mosquenow.app";

  static DatabaseReference get _db => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://mesquita-40d71-default-rtdb.europe-west1.firebasedatabase.app/',
      ).ref();

  static String normalizarUsername(String username) =>
      username.trim().toLowerCase();

  /// Email sintético usado só para autenticar o username no Firebase Auth.
  static String emailAuthParaUsername(String username) =>
      "${normalizarUsername(username)}@$_dominioAuth";

  static Future<bool> usernameDisponivel(String username) async {
    final snap =
        await _db.child("usernames/${normalizarUsername(username)}").get();
    return !snap.exists;
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

  /// Cria a conta Firebase Auth do requerente, reserva o username
  /// e grava o pedido em mesquitas_pendentes/{uid}.
  /// Retorna o UID (também usado como futuro ID da mesquita).
  static Future<String> registar({
    required String username,
    required String password,
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
    final chaveUsername = normalizarUsername(username);
    final usernameRef = _db.child("usernames/$chaveUsername");

    // Reserva atómica do username — evita corrida entre dois pedidos
    // com o mesmo nome em simultâneo.
    final transacao = await usernameRef.runTransaction((valorAtual) {
      if (valorAtual != null) return Transaction.abort();
      return Transaction.success(true);
    });

    if (!transacao.committed) {
      throw MesquitaRegistoException(
          "Esse nome de utilizador já está em uso. Escolha outro.");
    }

    UserCredential? credencial;
    try {
      credencial = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: "$chaveUsername@$_dominioAuth",
        password: password,
      );

      final uid = credencial.user!.uid;
      await usernameRef.set(uid);

      await _db.child("mesquitas_pendentes/$uid").set({
        "status": "pendente",
        "criado_em": ServerValue.timestamp,
        "username": chaveUsername,
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
    } on FirebaseAuthException catch (e) {
      await usernameRef.remove();
      throw MesquitaRegistoException(_traduzirErroAuth(e));
    } catch (e) {
      await usernameRef.remove();
      if (credencial?.user != null) {
        try {
          await credencial!.user!.delete();
        } catch (_) {}
      }
      throw MesquitaRegistoException(
          "Não foi possível concluir o registo. Verifique a sua ligação e tente novamente.");
    }
  }

  static String _traduzirErroAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return "Esse nome de utilizador já está em uso. Escolha outro.";
      case 'weak-password':
        return "A senha é demasiado fraca. Use pelo menos 8 caracteres.";
      case 'network-request-failed':
        return "Sem ligação à internet. Tente novamente.";
      default:
        return "Erro ao criar a conta (${e.code}). Tente novamente.";
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
    });

    // "mover": a mesquita já vive em mesquitas/{uid}, o pedido sai de pendente.
    await _db.child("mesquitas_pendentes/$uid").remove();
  }

  static Future<void> rejeitar(String uid, {String? motivo}) async {
    await _db.child("mesquitas_pendentes/$uid").update({
      "status": "rejeitado",
      "motivo_rejeicao": motivo ?? "",
      "rejeitado_em": ServerValue.timestamp,
    });
  }
}
