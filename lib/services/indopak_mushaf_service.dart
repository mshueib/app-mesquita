import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Palavra de uma linha do Mushaf: texto (script Indopak Nastaleeq),
/// número do versículo a que pertence e se é a última palavra desse
/// versículo (para desenhar a marca de fim de versículo depois dela).
class MushafWord {
  final String texto;
  final int ayah;
  final bool fimDeAyah;

  const MushafWord(this.texto, this.ayah, this.fimDeAyah);
}

sealed class MushafLinha {}

class LinhaTituloSura extends MushafLinha {
  final int surah;
  LinhaTituloSura(this.surah);
}

class LinhaBasmallah extends MushafLinha {}

class LinhaAyah extends MushafLinha {
  final List<MushafWord> palavras;
  LinhaAyah(this.palavras);
}

/// Fonte: layout "Indopak 13 lines (Qudratullah)" + texto "Indopak
/// Nastaleeq script - Word by Word", ambos da QUL (Quranic Universal
/// Library, projeto open-source da Tarteel.ai) — descarregados pelo
/// utilizador com a sua própria conta. As 849 páginas, com 13 linhas
/// cada, correspondem linha a linha ao Mushaf impresso Qudratullah.
class IndopakMushafService {
  static const int totalPaginas = 849;
  static const int linhasPorPagina = 13;

  // Frase inicial "Bismillah" — não vem indexada por palavra nos dados
  // de layout (as linhas "basmallah" não referenciam word_id), por
  // isso é escrita aqui tal como consta no texto árabe padrão.
  static const String basmallah = "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ";

  static List<List<MushafLinha>>? _paginas;

  static Future<List<List<MushafLinha>>> obterPaginas() async {
    if (_paginas != null) return _paginas!;

    final raw = await rootBundle.loadString('assets/quran/indopak_pages.json');
    final json = jsonDecode(raw);
    final paginasJson = json['pages'] as List;

    _paginas = [
      for (final paginaJson in paginasJson)
        [
          for (final linhaJson in (paginaJson as List))
            _parseLinha(linhaJson as List),
        ],
    ];

    return _paginas!;
  }

  static MushafLinha _parseLinha(List linha) {
    switch (linha[0]) {
      case 'S':
        return LinhaTituloSura(linha[1] as int);
      case 'B':
        return LinhaBasmallah();
      case 'A':
        final palavras = (linha[1] as List)
            .map((p) => MushafWord(
                  p[0] as String,
                  p[1] as int,
                  p[2] == 1,
                ))
            .toList();
        return LinhaAyah(palavras);
      default:
        throw Exception('Tipo de linha desconhecido no Mushaf: ${linha[0]}');
    }
  }

  /// Índice (0-based) da página onde aparece pela primeira vez um
  /// determinado versículo de uma sura.
  static int? paginaParaAyah(
    List<List<MushafLinha>> paginas,
    int surahAlvo,
    int ayahAlvo,
  ) {
    int? surahAtual;
    for (var i = 0; i < paginas.length; i++) {
      for (final linha in paginas[i]) {
        if (linha is LinhaTituloSura) {
          surahAtual = linha.surah;
        } else if (linha is LinhaAyah && surahAtual == surahAlvo) {
          for (final p in linha.palavras) {
            if (p.ayah == ayahAlvo) return i;
          }
        }
      }
    }
    return null;
  }

  /// Para cada página (por índice), a sura ainda ativa no início dessa
  /// página — antes de qualquer título de sura que apareça dentro
  /// dela. Necessário porque uma página pode começar a meio de uma
  /// sura (sem título próprio) quando a anterior termina no meio da
  /// página anterior.
  static List<int> surahInicialPorPagina(List<List<MushafLinha>> paginas) {
    final resultado = <int>[];
    var surahAtual = 1;
    for (final pagina in paginas) {
      resultado.add(surahAtual);
      for (final linha in pagina) {
        if (linha is LinhaTituloSura) surahAtual = linha.surah;
      }
    }
    return resultado;
  }

  /// Início (sura, ayah) de cada um dos 30 Juz do Alcorão — divisão
  /// padrão, igual em qualquer Mushaf impresso (não depende do layout
  /// de página nem varia por madhab).
  static const List<(int surah, int ayah)> _limitesJuz = [
    (1, 1), (2, 75), (2, 253), (3, 93), (4, 24), (4, 148), (5, 82), (6, 111),
    (7, 88), (8, 41), (9, 93), (11, 6), (12, 53), (15, 2), (17, 1), (18, 75),
    (21, 1), (23, 1), (25, 21), (27, 56), (29, 46), (33, 31), (36, 28),
    (39, 32), (41, 47), (46, 1), (51, 31), (58, 1), (67, 1), (78, 1),
  ];

  static int _comparaPosicao(int surah, int ayah, int surahAlvo, int ayahAlvo) {
    if (surah != surahAlvo) return surah - surahAlvo;
    return ayah - ayahAlvo;
  }

  /// Número do Juz (1 a 30) a que pertence uma posição (sura, ayah).
  static int juzParaPosicao(int surah, int ayah) {
    for (var i = _limitesJuz.length - 1; i >= 0; i--) {
      if (_comparaPosicao(surah, ayah, _limitesJuz[i].$1, _limitesJuz[i].$2) >= 0) {
        return i + 1;
      }
    }
    return 1;
  }

  /// Para cada página (por índice), o número do Juz (1 a 30) a que
  /// pertence o primeiro versículo dessa página. Calculado de forma
  /// independente por página (via [primeiroAyahDaPagina]) em vez de um
  /// contador acumulado ao longo do livro, para não arrastar um erro
  /// numa página para todas as seguintes.
  static List<int> juzInicialPorPagina(List<List<MushafLinha>> paginas) {
    final resultado = <int>[];
    var ultimoJuz = 1;
    for (var i = 0; i < paginas.length; i++) {
      final primeiro = primeiroAyahDaPagina(paginas, i);
      if (primeiro != null) {
        ultimoJuz = juzParaPosicao(primeiro.$1, primeiro.$2);
      }
      resultado.add(ultimoJuz);
    }
    return resultado;
  }

  /// Primeiro versículo (sura, ayah) que aparece numa página — usado
  /// para "marcar esta página" quando não se toca num versículo
  /// específico.
  static (int surah, int ayah)? primeiroAyahDaPagina(
    List<List<MushafLinha>> paginas,
    int indicePagina,
  ) {
    int? surahAtual;
    // Procura o título de sura mais recente até esta página, para o
    // caso de a página começar a meio de uma sura sem título próprio.
    for (var i = 0; i <= indicePagina; i++) {
      for (final linha in paginas[i]) {
        if (linha is LinhaTituloSura) surahAtual = linha.surah;
        if (i == indicePagina && linha is LinhaAyah && linha.palavras.isNotEmpty) {
          if (surahAtual == null) continue;
          return (surahAtual, linha.palavras.first.ayah);
        }
      }
    }
    return null;
  }
}
