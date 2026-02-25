import 'dart:convert';
import 'package:crypto/crypto.dart';

class AuthService {
  static const _hashedPassword =
      'aee949757a2e6984171d5b8e4df9a7f3d1a6d3c8f0f4f7c21b88a3d3a0c7bdf3';

  static bool validate(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes).toString();
    return hash == _hashedPassword;
  }
}
