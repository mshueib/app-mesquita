class AvisoModel {
  final String id;
  final String tipo;
  final String texto;
  final String prazo;

  AvisoModel({
    required this.id,
    required this.tipo,
    required this.texto,
    required this.prazo,
  });

  factory AvisoModel.fromMap(String id, Map map) {
    return AvisoModel(
      id: id,
      tipo: map['tipo'] ?? 'geral',
      texto: map['texto'] ?? '',
      prazo: map['prazo'] ?? '',
    );
  }
}
