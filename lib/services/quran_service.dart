import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'local_storage_service.dart';

class SurahInfo {
  final int numero;
  final String nome;
  final int juzInicial;

  const SurahInfo(this.numero, this.nome, this.juzInicial);
}

class QuranMarcador {
  final String nome;
  final int juz;
  final int pagina;
  final DateTime criadoEm;

  QuranMarcador({
    required this.nome,
    required this.juz,
    required this.pagina,
    required this.criadoEm,
  });

  Map<String, dynamic> toJson() => {
        "nome": nome,
        "juz": juz,
        "pagina": pagina,
        "criadoEm": criadoEm.toIso8601String(),
      };

  factory QuranMarcador.fromJson(Map<String, dynamic> json) => QuranMarcador(
        nome: json["nome"] as String? ?? "Marcador",
        juz: json["juz"] as int,
        pagina: json["pagina"] as int,
        criadoEm: DateTime.parse(json["criadoEm"] as String),
      );
}

/// Mushaf de 13 linhas em PDF, um ficheiro por juz, publicado por
/// dawatehidayat.org. Cada juz é descarregado na primeira vez que é
/// aberto e fica guardado no telemóvel para leitura offline.
class QuranService {
  static const int totalJuz = 30;

  static String urlJuz(int juz) =>
      "https://dawatehidayat.org/downloads/quran/13line/"
      "juz${juz.toString().padLeft(2, '0')}.pdf";

  static Future<File> ficheiroJuz(int juz) async {
    final base = await getApplicationDocumentsDirectory();
    final pasta = Directory("${base.path}/quran13");
    if (!await pasta.exists()) await pasta.create(recursive: true);
    return File("${pasta.path}/juz${juz.toString().padLeft(2, '0')}.pdf");
  }

  static Future<bool> juzDescarregado(int juz) async =>
      (await ficheiroJuz(juz)).exists();

  static Future<Set<int>> juzesDescarregados() async {
    final resultado = <int>{};
    for (var juz = 1; juz <= totalJuz; juz++) {
      if (await juzDescarregado(juz)) resultado.add(juz);
    }
    return resultado;
  }

  /// Descarrega o PDF do juz. Grava primeiro num ficheiro ".part" e só
  /// o renomeia no fim — assim um download interrompido nunca fica
  /// confundido com um PDF completo.
  ///
  /// Se o mesmo juz já estiver a ser descarregado (ex: pelo "Descarregar
  /// tudo" enquanto o utilizador o abre), reutiliza esse download em vez
  /// de ter dois a escrever no mesmo ficheiro.
  static Future<File> descarregarJuz(
    int juz, {
    void Function(double progresso)? onProgresso,
  }) {
    final emCurso = _downloadsEmCurso[juz];
    if (emCurso != null) {
      _ouvintesProgresso[juz]?.add(onProgresso);
      return emCurso;
    }
    _ouvintesProgresso[juz] = [onProgresso];
    final futuro = _descarregarJuz(juz, (p) {
      for (final ouvinte in _ouvintesProgresso[juz] ?? const []) {
        ouvinte?.call(p);
      }
    }).whenComplete(() {
      _downloadsEmCurso.remove(juz);
      _ouvintesProgresso.remove(juz);
    });
    _downloadsEmCurso[juz] = futuro;
    return futuro;
  }

  static final Map<int, Future<File>> _downloadsEmCurso = {};
  static final Map<int, List<void Function(double)?>> _ouvintesProgresso = {};

  static Future<File> _descarregarJuz(
    int juz,
    void Function(double progresso) onProgresso,
  ) async {
    final destino = await ficheiroJuz(juz);
    final temporario = File("${destino.path}.part");

    final cliente = http.Client();
    try {
      final resposta =
          await cliente.send(http.Request("GET", Uri.parse(urlJuz(juz))));
      if (resposta.statusCode != 200) {
        throw HttpException("Erro ${resposta.statusCode} ao descarregar o Juz $juz");
      }

      final total = resposta.contentLength ?? 0;
      var recebido = 0;
      final escrita = temporario.openWrite();
      try {
        await for (final bloco in resposta.stream) {
          escrita.add(bloco);
          recebido += bloco.length;
          if (total > 0) onProgresso(recebido / total);
        }
      } finally {
        await escrita.close();
      }

      return await temporario.rename(destino.path);
    } catch (_) {
      if (await temporario.exists()) await temporario.delete();
      rethrow;
    } finally {
      cliente.close();
    }
  }

  // ---------------- Descarregar o Alcorão completo ----------------

  /// Juz a ser descarregado neste momento pelo "Descarregar tudo"
  /// (null = parado). Fica no serviço, e não no ecrã, para o download
  /// continuar se o utilizador mudar de separador.
  static final ValueNotifier<int?> downloadTudoJuz = ValueNotifier(null);

  /// Progresso (0–1) do Alcorão completo.
  static final ValueNotifier<double> downloadTudoProgresso = ValueNotifier(0);

  static bool _cancelarDownloadTudo = false;

  static bool get aDescarregarTudo => downloadTudoJuz.value != null;

  /// Descarrega, um a um, os juz que ainda faltam. Devolve quantos
  /// falharam (0 = tudo certo). Um cancelamento só tem efeito entre
  /// juz, para nunca deixar um ficheiro a meio.
  static Future<int> descarregarTudo() async {
    if (aDescarregarTudo) return 0;
    _cancelarDownloadTudo = false;
    var falhas = 0;

    try {
      for (var juz = 1; juz <= totalJuz; juz++) {
        if (_cancelarDownloadTudo) break;
        downloadTudoJuz.value = juz;
        downloadTudoProgresso.value = (juz - 1) / totalJuz;
        if (await juzDescarregado(juz)) continue;

        try {
          await descarregarJuz(juz, onProgresso: (p) {
            downloadTudoProgresso.value = (juz - 1 + p) / totalJuz;
          });
        } catch (_) {
          falhas++;
        }
      }
    } finally {
      downloadTudoJuz.value = null;
      downloadTudoProgresso.value = 0;
    }
    return falhas;
  }

  static void cancelarDownloadTudo() => _cancelarDownloadTudo = true;

  static Future<void> apagarJuz(int juz) async {
    final ficheiro = await ficheiroJuz(juz);
    if (await ficheiro.exists()) await ficheiro.delete();
  }

  // ---------------- Marcadores (por página, únicos por página) ----------------

  static Future<List<QuranMarcador>> listarMarcadores() async {
    final lista = await LocalStorageService.carregarMarcadoresQuran();
    return lista.map(QuranMarcador.fromJson).toList()
      ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
  }

  /// Grava um marcador nomeado. Se já existir um marcador nesta página
  /// exacta, substitui-o (nome + data) em vez de duplicar.
  static Future<void> salvarMarcador(QuranMarcador marcador) async {
    final lista = await LocalStorageService.carregarMarcadoresQuran();
    lista.removeWhere(
      (m) => m["juz"] == marcador.juz && m["pagina"] == marcador.pagina,
    );
    lista.add(marcador.toJson());
    await LocalStorageService.salvarMarcadoresQuran(lista);
  }

  static Future<void> removerMarcador(DateTime criadoEm) async {
    final lista = await LocalStorageService.carregarMarcadoresQuran();
    lista.removeWhere((m) => m["criadoEm"] == criadoEm.toIso8601String());
    await LocalStorageService.salvarMarcadoresQuran(lista);
  }

  // ---------------- Continuar leitura (automático) ----------------

  static Future<void> registarUltimaLeitura(int juz, int pagina) {
    return LocalStorageService.salvarUltimaLeituraQuran(juz, pagina);
  }

  static Future<Map<String, dynamic>?> obterUltimaLeitura() {
    return LocalStorageService.carregarUltimaLeituraQuran();
  }

  // ---------------- Índice de suras → juz onde começam ----------------

  static List<SurahInfo> listarSurahs() => _suras;

  // Página impressa (número no topo da página do Mushaf) onde começa cada
  // juz e cada sura. Gerado a partir do layout "Indopak 13 linhas" (QUL) e
  // confirmado nos PDFs: o PDF do Juz N começa na página impressa
  // _paginaImpressaJuz[N-1] (o do Juz 1 começa na capa, página 1).
  static const List<int> _paginaImpressaJuz = [
    1, 29, 57, 85, 113, 141, 168, 197, 225, 253, 280, 309, 337, 364, 393, //
    421, 449, 477, 505, 532, 559, 587, 613, 641, 667, 697, 727, 757, 787, 819,
  ];

  static const List<int> _paginaImpressaSura = [
    2, 3, 67, 106, 147, 177, 209, 246, 260, 289, 308, 327, 346, 355, 364, //
    372, 393, 409, 425, 435, 449, 462, 477, 488, 501, 511, 525, 537, 552, //
    562, 571, 577, 581, 595, 603, 611, 618, 628, 635, 647, 660, 668, 677, //
    687, 691, 697, 704, 710, 716, 720, 725, 729, 733, 737, 741, 745, 750, //
    757, 762, 767, 771, 773, 775, 777, 780, 784, 787, 790, 794, 797, 800, //
    803, 806, 808, 811, 813, 816, 819, 821, 823, 825, 826, 827, 829, 830, //
    832, 832, 833, 835, 836, 837, 838, 839, 840, 840, 841, 842, 842, 843, //
    844, 844, 845, 845, 846, 846, 847, 847, 848, 848, 848, 849, 849, 849, 850,
  ];

  /// Página dentro do PDF do juz onde começa a sura [numero].
  static int paginaDaSuraNoJuz(SurahInfo sura) {
    final impressa = _paginaImpressaSura[sura.numero - 1];
    return impressa - _paginaImpressaJuz[sura.juzInicial - 1] + 1;
  }

  static const List<int> surasPrincipais = [1, 36, 18, 32, 55, 56, 67];

  static SurahInfo? porNumero(int numero) =>
      (numero >= 1 && numero <= _suras.length) ? _suras[numero - 1] : null;

  static const List<SurahInfo> _suras = [
    SurahInfo(1, "Al-Faatiha", 1),
    SurahInfo(2, "Al-Baqara", 1),
    SurahInfo(3, "Aal-i-Imraan", 3),
    SurahInfo(4, "An-Nisaa", 4),
    SurahInfo(5, "Al-Maaida", 6),
    SurahInfo(6, "Al-An'aam", 7),
    SurahInfo(7, "Al-A'raaf", 8),
    SurahInfo(8, "Al-Anfaal", 9),
    SurahInfo(9, "At-Tawba", 10),
    SurahInfo(10, "Yunus", 11),
    SurahInfo(11, "Hud", 11),
    SurahInfo(12, "Yusuf", 12),
    SurahInfo(13, "Ar-Ra'd", 13),
    SurahInfo(14, "Ibrahim", 13),
    SurahInfo(15, "Al-Hijr", 14),
    SurahInfo(16, "An-Nahl", 14),
    SurahInfo(17, "Al-Israa", 15),
    SurahInfo(18, "Al-Kahf", 15),
    SurahInfo(19, "Maryam", 16),
    SurahInfo(20, "Taa-Haa", 16),
    SurahInfo(21, "Al-Anbiyaa", 17),
    SurahInfo(22, "Al-Hajj", 17),
    SurahInfo(23, "Al-Muminoon", 18),
    SurahInfo(24, "An-Noor", 18),
    SurahInfo(25, "Al-Furqaan", 18),
    SurahInfo(26, "Ash-Shu'araa", 19),
    SurahInfo(27, "An-Naml", 19),
    SurahInfo(28, "Al-Qasas", 20),
    SurahInfo(29, "Al-Ankaboot", 20),
    SurahInfo(30, "Ar-Room", 21),
    SurahInfo(31, "Luqman", 21),
    SurahInfo(32, "As-Sajda", 21),
    SurahInfo(33, "Al-Ahzaab", 21),
    SurahInfo(34, "Saba", 22),
    SurahInfo(35, "Faatir", 22),
    SurahInfo(36, "Yaseen", 22),
    SurahInfo(37, "As-Saaffaat", 23),
    SurahInfo(38, "Saad", 23),
    SurahInfo(39, "Az-Zumar", 23),
    SurahInfo(40, "Ghafir", 24),
    SurahInfo(41, "Fussilat", 24),
    SurahInfo(42, "Ash-Shura", 25),
    SurahInfo(43, "Az-Zukhruf", 25),
    SurahInfo(44, "Ad-Dukhaan", 25),
    SurahInfo(45, "Al-Jaathiya", 25),
    SurahInfo(46, "Al-Ahqaf", 26),
    SurahInfo(47, "Muhammad", 26),
    SurahInfo(48, "Al-Fath", 26),
    SurahInfo(49, "Al-Hujuraat", 26),
    SurahInfo(50, "Qaaf", 26),
    SurahInfo(51, "Adh-Dhaariyat", 26),
    SurahInfo(52, "At-Tur", 27),
    SurahInfo(53, "An-Najm", 27),
    SurahInfo(54, "Al-Qamar", 27),
    SurahInfo(55, "Ar-Rahmaan", 27),
    SurahInfo(56, "Al-Waaqia", 27),
    SurahInfo(57, "Al-Hadid", 27),
    SurahInfo(58, "Al-Mujaadila", 28),
    SurahInfo(59, "Al-Hashr", 28),
    SurahInfo(60, "Al-Mumtahana", 28),
    SurahInfo(61, "As-Saff", 28),
    SurahInfo(62, "Al-Jumu'a", 28),
    SurahInfo(63, "Al-Munaafiqoon", 28),
    SurahInfo(64, "At-Taghaabun", 28),
    SurahInfo(65, "At-Talaaq", 28),
    SurahInfo(66, "At-Tahrim", 28),
    SurahInfo(67, "Al-Mulk", 29),
    SurahInfo(68, "Al-Qalam", 29),
    SurahInfo(69, "Al-Haaqqa", 29),
    SurahInfo(70, "Al-Ma'aarij", 29),
    SurahInfo(71, "Nooh", 29),
    SurahInfo(72, "Al-Jinn", 29),
    SurahInfo(73, "Al-Muzzammil", 29),
    SurahInfo(74, "Al-Muddaththir", 29),
    SurahInfo(75, "Al-Qiyaama", 29),
    SurahInfo(76, "Al-Insaan", 29),
    SurahInfo(77, "Al-Mursalaat", 29),
    SurahInfo(78, "An-Naba", 30),
    SurahInfo(79, "An-Naazi'aat", 30),
    SurahInfo(80, "Abasa", 30),
    SurahInfo(81, "At-Takwir", 30),
    SurahInfo(82, "Al-Infitaar", 30),
    SurahInfo(83, "Al-Mutaffifin", 30),
    SurahInfo(84, "Al-Inshiqaaq", 30),
    SurahInfo(85, "Al-Burooj", 30),
    SurahInfo(86, "At-Taariq", 30),
    SurahInfo(87, "Al-A'laa", 30),
    SurahInfo(88, "Al-Ghaashiya", 30),
    SurahInfo(89, "Al-Fajr", 30),
    SurahInfo(90, "Al-Balad", 30),
    SurahInfo(91, "Ash-Shams", 30),
    SurahInfo(92, "Al-Lail", 30),
    SurahInfo(93, "Ad-Dhuhaa", 30),
    SurahInfo(94, "Ash-Sharh", 30),
    SurahInfo(95, "At-Tin", 30),
    SurahInfo(96, "Al-Alaq", 30),
    SurahInfo(97, "Al-Qadr", 30),
    SurahInfo(98, "Al-Bayyina", 30),
    SurahInfo(99, "Az-Zalzala", 30),
    SurahInfo(100, "Al-Aadiyaat", 30),
    SurahInfo(101, "Al-Qaari'a", 30),
    SurahInfo(102, "At-Takaathur", 30),
    SurahInfo(103, "Al-Asr", 30),
    SurahInfo(104, "Al-Humaza", 30),
    SurahInfo(105, "Al-Fil", 30),
    SurahInfo(106, "Quraish", 30),
    SurahInfo(107, "Al-Maa'un", 30),
    SurahInfo(108, "Al-Kawthar", 30),
    SurahInfo(109, "Al-Kaafiroon", 30),
    SurahInfo(110, "An-Nasr", 30),
    SurahInfo(111, "Al-Masad", 30),
    SurahInfo(112, "Al-Ikhlaas", 30),
    SurahInfo(113, "Al-Falaq", 30),
    SurahInfo(114, "An-Naas", 30),
  ];
}
