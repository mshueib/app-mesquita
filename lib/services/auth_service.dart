import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static Future<bool> login(String pinDigitado) async {
    try {
      // 1️⃣ Buscar PIN do Firebase
      final ref = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://mesquita-40d71-default-rtdb.europe-west1.firebasedatabase.app/',
      ).ref("app/admin_pin");

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
