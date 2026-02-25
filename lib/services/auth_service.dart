class AuthService {
  static const String _adminPassword = "Mosque@\$26";

  static bool login(String password) {
    return password == _adminPassword;
  }
}
