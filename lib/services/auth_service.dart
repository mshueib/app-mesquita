class AuthService {
  static const String _adminPassword = "Mosque@Quel26";

  static bool login(String password) {
    return password == _adminPassword;
  }
}
