import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class DuaCategoria {
  final String slug;
  final String nome;
  final int total;

  DuaCategoria({required this.slug, required this.nome, required this.total});
}

class Dua {
  final String titulo;
  final String arabe;
  final String latim;
  final String traducao;
  final String notas;
  final String fonte;

  Dua({
    required this.titulo,
    required this.arabe,
    required this.latim,
    required this.traducao,
    required this.notas,
    required this.fonte,
  });
}

/// Duas/Dhikr — mesma estrutura e categorias do dua-dhikr
/// (https://github.com/fitrahive/dua-dhikr, MIT), com tradução para
/// português. Fica embutido como asset da app (sem rede, sempre
/// disponível offline).
class DuaService {
  static Map<String, dynamic>? _dadosCache;

  static Future<Map<String, dynamic>> _carregar() async {
    if (_dadosCache != null) return _dadosCache!;
    final raw = await rootBundle.loadString('assets/quran/duas_pt.json');
    _dadosCache = jsonDecode(raw) as Map<String, dynamic>;
    return _dadosCache!;
  }

  static Future<List<DuaCategoria>> listarCategorias() async {
    final dados = await _carregar();
    final categorias = dados['categorias'] as List;
    return categorias
        .map((c) => DuaCategoria(
              slug: c['slug'] as String,
              nome: c['nome'] as String,
              total: (c['itens'] as List).length,
            ))
        .toList();
  }

  static Future<List<Dua>> obterCategoria(String slug) async {
    final dados = await _carregar();
    final categorias = dados['categorias'] as List;
    final categoria = categorias.firstWhere((c) => c['slug'] == slug);
    final itens = categoria['itens'] as List;

    return itens
        .map((i) => Dua(
              titulo: i['titulo'] as String? ?? "",
              arabe: i['arabe'] as String? ?? "",
              latim: i['latim'] as String? ?? "",
              traducao: i['traducao'] as String? ?? "",
              notas: i['notas'] as String? ?? "",
              fonte: i['fonte'] as String? ?? "",
            ))
        .toList();
  }
}
