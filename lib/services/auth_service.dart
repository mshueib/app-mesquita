import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Login por PIN (admin de uma mesquita / super-admin).
///
/// O PIN é verificado no servidor pela Cloud Function `loginComPin` — a
/// app nunca vê o PIN correcto. Se estiver certo, a função dá à sessão
/// um custom claim ("mesquita" ou "superAdmin") que as regras da base de
/// dados exigem para escrever.
class AuthService {
  static Future<bool> login(String pinDigitado, {required String mesquitaId}) {
    return _loginComPin(pinDigitado, tipo: "admin", mesquitaId: mesquitaId);
  }

  static Future<bool> loginSuperAdmin(String pinDigitado) {
    return _loginComPin(pinDigitado, tipo: "superAdmin");
  }

  static Future<bool> _loginComPin(
    String pinDigitado, {
    required String tipo,
    String? mesquitaId,
  }) async {
    try {
      final auth = FirebaseAuth.instance;
      // A função precisa de saber quem receber o claim — uma sessão
      // anónima chega (ou a sessão Google, se já houver uma).
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }

      final resultado = await FirebaseFunctions.instanceFor(
        region: "europe-west1",
      ).httpsCallable("loginComPin").call({
        "pin": pinDigitado.trim(),
        "tipo": tipo,
        if (mesquitaId != null) "mesquitaId": mesquitaId,
      });

      final ok = (resultado.data as Map?)?["ok"] == true;
      if (ok) {
        // Força um token novo, já com o claim, antes de escrever na base
        // de dados.
        await auth.currentUser!.getIdToken(true);
      }
      return ok;
    } on FirebaseFunctionsException catch (e) {
      print("Erro ao verificar PIN: ${e.code} ${e.message}");
      return false;
    } catch (e) {
      print("Erro ao verificar PIN: $e");
      return false;
    }
  }

  static Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }
}
