import 'package:flutter/services.dart';

/// Toca o Azan num serviço Android em primeiro plano, agendado por
/// alarmes exactos. Ao contrário do som de uma notificação, não é
/// silenciado ao abrir a barra de notificações — só pára com
/// "Parar Azan", uma tecla de volume, ou no fim do áudio.
class AzanPlayer {
  static const MethodChannel _canal = MethodChannel('com.mosque.now/azan_player');

  /// Agenda (ou substitui) o Azan diário com este [id].
  static Future<void> agendar({
    required int id,
    required String nome,
    required int hora,
    required int minuto,
  }) {
    return _canal.invokeMethod('agendar', {
      'id': id,
      'nome': nome,
      'hora': hora,
      'minuto': minuto,
    });
  }

  /// Cancela os Azan agendados (não pára um que esteja a tocar).
  static Future<void> cancelarTodos() => _canal.invokeMethod('cancelarTodos');

  /// Toca o Azan agora — útil para testar som e volume.
  static Future<void> testar({String nome = "Teste"}) =>
      _canal.invokeMethod('testar', {'nome': nome});

  static Future<void> parar() => _canal.invokeMethod('parar');
}
