import 'package:flutter/material.dart';

/// Ponto único para navegação por push, evitando repetir
/// `Navigator.push(context, MaterialPageRoute(...))` em cada ecrã.
class NavHelper {
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }
}
