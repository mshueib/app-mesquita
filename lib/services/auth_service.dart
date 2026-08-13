import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static Future<bool> login(String pinDigitado) {
    return _loginComPin("app/admin_pin", pinDigitado);
  }

  static Future<bool> loginSuperAdmin(String pinDigitado) {
    return _loginComPin("app/super_admin_pin", pinDigitado);
  }

  static Future<bool> _loginComPin(String caminhoPin, String pinDigitado) async {
    try {
      // 1️⃣ Buscar PIN do Firebase
      final ref = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://mesquita-40d71-default-rtdb.europe-west1.firebasedatabase.app/',
      ).ref(caminhoPin);

      final snapshot = await ref.get();

      if (!snapshot.exists) return false;

      final pinCorreto = snapshot.value.toString();

      // 2️⃣ Verificar PIN
      if (pinDigitado.trim() != pinCorreto.trim()) return false;

      // 3️⃣ PIN correcto → autenticar anonimamente para ter permissão de escrita
      await FirebaseAuth.instance.signInAnonymously();

      return true;
    } catch (e) {
      print("Erro ao verificar PIN: $e");
      return false;
    }
  }

  static Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }
}
