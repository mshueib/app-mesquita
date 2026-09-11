import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/quran_service.dart';
import '../services/indopak_mushaf_service.dart';
import 'quran_marcadores_page.dart';

const List<String> _numeraisArabes = [
  "٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩",
];

String _numeralArabe(int n) =>
    n.toString().split('').map((d) => _numeraisArabes[int.parse(d)]).join();

// Marca de fim de versículo tradicional do Alcorão (U+06DD) + número
// em algarismos arábicos, como num Mushaf impresso.
String _marcadorAyah(int numero) => "۝${_numeralArabe(numero)}";

const String _fonteMushaf = "IndopakNastaleeq";

const TextStyle _estiloTextoAyah = TextStyle(
  fontSize: 26,
  color: Colors.black87,
  fontFamily: _fonteMushaf,
);

const TextStyle _estiloMarcadorAyah = TextStyle(
  fontSize: 22,
  color: Color(0xFFB8860B),
  fontWeight: FontWeight.bold,
  fontFamily: _fonteMushaf,
);

const TextStyle _estiloCabecalhoSura = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.bold,
  color: Color(0xFF0B3D2E),
);

const TextStyle _estiloBasmallah = TextStyle(
  fontSize: 24,
  color: Color(0xFF0B3D2E),
  fontFamily: _fonteMushaf,
);

/// Lista de suras — vive dentro do PageView principal (sem AppBar
/// própria). Ao tocar numa sura, abre [SurahPage] via Navigator.
class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  final List<SurahInfo> _suras = QuranService.listarSurahs();
  final TextEditingController _pesquisaController = TextEditingController();

  Map<String, dynamic>? _ultimaLeitura;
  String _pesquisa = "";

  @override
  void initState() {
    super.initState();
    _verificarEstado();
    _pesquisaController.addListener(() {
      setState(() => _pesquisa = _pesquisaController.text.trim());
    });
  }

  @override
  void dispose() {
    _pesquisaController.dispose();
    super.dispose();
  }

  Future<void> _verificarEstado() async {
    final ultimaLeitura = await QuranService.obterUltimaLeitura();
    if (!mounted) return;
    setState(() {
      _ultimaLeitura = ultimaLeitura;
    });
  }

  void _abrirSurah(SurahInfo sura, {int? ayahInicial}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahPage(sura: sura, ayahInicial: ayahInicial),
      ),
    ).then((_) => _verificarEstado());
  }

  List<SurahInfo> get _surasFiltradas {
    if (_pesquisa.isEmpty) return _suras;
    final termo = _pesquisa.toLowerCase();
    return _suras.where((s) {
      return s.numero.toString() == termo ||
          s.nomeIngles.toLowerCase().contains(termo) ||
          s.traducaoIngles.toLowerCase().contains(termo) ||
          s.nomeArabe.contains(_pesquisa);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final surasFiltradas = _surasFiltradas;

    return Container(
      color: const Color(0xFFF4F1EA),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _cabecalho()),
          if (surasFiltradas.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    "Nenhuma sura encontrada.",
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ),
            )
          else
            SliverList.separated(
              itemCount: surasFiltradas.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final sura = surasFiltradas[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF0B3D2E),
                    foregroundColor: Colors.white,
                    child: Text("${sura.numero}"),
                  ),
                  title: Text(
                    sura.nomeIngles,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${sura.traducaoIngles} · ${sura.numeroAyahs} versículos",
                  ),
                  trailing: Text(
                    sura.nomeArabe,
                    style: const TextStyle(fontSize: 18),
                    textDirection: TextDirection.rtl,
                  ),
                  onTap: () => _abrirSurah(sura),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _campoPesquisa() {
    return TextField(
      controller: _pesquisaController,
      decoration: InputDecoration(
        hintText: "Pesquisar sura (nome, tema, número...)",
        prefixIcon: const Icon(Icons.search, color: Color(0xFF0B3D2E)),
        suffixIcon: _pesquisa.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear, color: Colors.black45),
                onPressed: _pesquisaController.clear,
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFF0B3D2E)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFF0B3D2E)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
        ),
      ),
    );
  }

  Widget _cabecalho() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const QuranMarcadoresPage(),
                    ),
                  ),
                  icon: const Icon(Icons.bookmark, color: Color(0xFF0B3D2E)),
                  label: const Text(
                    "Marcadores",
                    style: TextStyle(color: Color(0xFF0B3D2E)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0B3D2E)),
                  ),
                ),
              ),
            ],
          ),
          if (_ultimaLeitura != null) ...[
            const SizedBox(height: 12),
            _cardContinuarLeitura(),
          ],
          const SizedBox(height: 20),
          _campoPesquisa(),
          if (_pesquisa.isEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              "Suras principais",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            _listaSurasPrincipais(),
          ],
          const SizedBox(height: 20),
          Text(
            _pesquisa.isEmpty ? "Todas as suras" : "Resultados",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _cardContinuarLeitura() {
    final surahNum = _ultimaLeitura!["surah"] as int;
    final ayah = _ultimaLeitura!["ayah"] as int;
    final sura = QuranService.porNumero(surahNum);
    if (sura == null) return const SizedBox();

    return GestureDetector(
      onTap: () => _abrirSurah(sura, ayahInicial: ayah),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B3D2E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_circle_fill, color: Color(0xFFD4AF37)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Continuar leitura",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    "${sura.nomeIngles} · versículo $ayah",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _listaSurasPrincipais() {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: QuranService.suasPrincipais.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final sura = QuranService.porNumero(QuranService.suasPrincipais[index]);
          if (sura == null) return const SizedBox();
          return GestureDetector(
            onTap: () => _abrirSurah(sura),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE6F2ED),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF0B3D2E)),
              ),
              child: Text(
                sura.nomeIngles,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B3D2E),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SurahPage extends StatefulWidget {
  final SurahInfo sura;
  final int? ayahInicial;

  const SurahPage({super.key, required this.sura, this.ayahInicial});

  @override
  State<SurahPage> createState() => _SurahPageState();
}

class _SurahPageState extends State<SurahPage> {
  late Future<List<List<MushafLinha>>> _futurePaginas;
  final Map<int, TapGestureRecognizer> _recognizers = {};

  late PageController _pageController;
  int _paginaAtual = 0;
  bool _jaSaltou = false;
  List<int>? _surahInicialPorPagina;
  List<int>? _juzInicialPorPagina;

  @override
  void initState() {
    super.initState();
    _futurePaginas = IndopakMushafService.obterPaginas();
    _pageController = PageController();
  }

  @override
  void dispose() {
    for (final r in _recognizers.values) {
      r.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  TapGestureRecognizer _recognizerPara(MushafWord palavra, int surahAtual) {
    final chave = surahAtual * 1000 + palavra.ayah;
    return _recognizers.putIfAbsent(
      chave,
      () => TapGestureRecognizer()
        ..onTap = () => _abrirDialogoMarcador(surahAtual, palavra.ayah),
    );
  }

  void _saltarParaAlvoSeNecessario(List<List<MushafLinha>> paginas) {
    if (_jaSaltou) return;
    _jaSaltou = true;

    final indice = IndopakMushafService.paginaParaAyah(
      paginas,
      widget.sura.numero,
      widget.ayahInicial ?? 1,
    );
    if (indice == null || indice <= 0) return;

    _paginaAtual = indice;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(indice);
      }
    });
  }

  Future<void> _abrirDialogoMarcador(int surah, int ayah) async {
    final sura = QuranService.porNumero(surah);
    final controller = TextEditingController(
      text: sura != null ? "${sura.nomeIngles} $ayah" : "Marcador",
    );

    final nome = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Novo marcador"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: "Nome do marcador"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0B3D2E),
              foregroundColor: Colors.white,
            ),
            child: const Text("Guardar"),
          ),
        ],
      ),
    );

    if (nome == null || nome.isEmpty) return;

    await QuranService.salvarMarcador(
      QuranMarcador(
        nome: nome,
        surah: surah,
        ayah: ayah,
        surahNome: sura?.nomeIngles ?? "",
        criadoEm: DateTime.now(),
      ),
    );
    await QuranService.registarUltimaLeitura(surah, ayah);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Marcador "$nome" guardado'),
        backgroundColor: const Color(0xFF0B3D2E),
      ),
    );
  }

  void _novoMarcadorPaginaAtual(List<List<MushafLinha>> paginas) {
    final alvo = IndopakMushafService.primeiroAyahDaPagina(
      paginas,
      _paginaAtual,
    );
    if (alvo == null) return;
    _abrirDialogoMarcador(alvo.$1, alvo.$2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3D2E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Alcorão", style: TextStyle(color: Colors.white)),
        actions: [
          FutureBuilder<List<List<MushafLinha>>>(
            future: _futurePaginas,
            builder: (context, snapshot) {
              return IconButton(
                icon: const Icon(Icons.bookmark_add, color: Colors.white),
                tooltip: "Novo marcador",
                onPressed: snapshot.hasData
                    ? () => _novoMarcadorPaginaAtual(snapshot.data!)
                    : null,
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<List<MushafLinha>>>(
        future: _futurePaginas,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0B3D2E)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      "Não foi possível carregar o Alcorão.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {
                        _futurePaginas = IndopakMushafService.obterPaginas();
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B3D2E),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Tentar novamente"),
                    ),
                  ],
                ),
              ),
            );
          }

          final paginas = snapshot.data!;
          _saltarParaAlvoSeNecessario(paginas);
          _surahInicialPorPagina ??=
              IndopakMushafService.surahInicialPorPagina(paginas);
          _juzInicialPorPagina ??=
              IndopakMushafService.juzInicialPorPagina(paginas);

          return Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  reverse: true, // páginas do Alcorão avançam da direita para a esquerda
                  itemCount: paginas.length,
                  onPageChanged: (i) => setState(() => _paginaAtual = i),
                  itemBuilder: (context, index) {
                    final juzDaPagina = _juzInicialPorPagina![index];
                    final juzAnterior =
                        index == 0 ? null : _juzInicialPorPagina![index - 1];
                    final juzNovo = juzDaPagina != juzAnterior ? juzDaPagina : null;
                    return _paginaWidget(
                      paginas[index],
                      _surahInicialPorPagina![index],
                      MediaQuery.of(context).size.width - 32,
                      juzNovo: juzNovo,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Builder(
                  builder: (context) {
                    final suraAtual = QuranService.porNumero(
                        _surahInicialPorPagina![_paginaAtual]);
                    final juzAtual = _juzInicialPorPagina![_paginaAtual];
                    final prefixo = suraAtual != null
                        ? "${suraAtual.nomeIngles} — "
                        : "";
                    return Text(
                      "${prefixo}Juz $juzAtual — Página ${_paginaAtual + 1} de ${paginas.length}",
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Mede a largura natural (numa só linha) que uma linha de versículos
  // ocuparia no tamanho de letra base — para depois calcular UMA
  // escala só, aplicada a todas as linhas da página por igual.
  double _medirLarguraLinha(LinhaAyah linha) {
    final spans = <InlineSpan>[];
    for (final p in linha.palavras) {
      spans.add(TextSpan(text: "${p.texto} ", style: _estiloTextoAyah));
      if (p.fimDeAyah) {
        spans.add(TextSpan(
          text: " ${_marcadorAyah(p.ayah)} ",
          style: _estiloMarcadorAyah,
        ));
      }
    }
    final tp = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.rtl,
      maxLines: 1,
    )..layout();
    final largura = tp.width;
    tp.dispose();
    return largura;
  }

  Widget _paginaWidget(
    List<MushafLinha> pagina,
    int surahInicial,
    double larguraDisponivel, {
    int? juzNovo,
  }) {
    // Segue o número da sura ao longo da página, para os
    // reconhecedores de toque saberem a que sura cada versículo
    // pertence (os dados de layout só indicam a sura no título, que
    // pode mudar a meio da página se houver suras curtas).
    int surahAtual = surahInicial;

    // Uma única escala para a página inteira — baseada na linha mais
    // larga — em vez de cada linha escalar de forma independente
    // (o que fazia o tamanho de letra variar de linha para linha).
    double maiorLargura = 0;
    for (final linha in pagina) {
      if (linha is LinhaAyah) {
        final largura = _medirLarguraLinha(linha);
        if (largura > maiorLargura) maiorLargura = largura;
      }
    }
    final escala = maiorLargura > larguraDisponivel
        ? (larguraDisponivel / maiorLargura).clamp(0.4, 1.0)
        : 1.0;

    final estiloTexto =
        _estiloTextoAyah.copyWith(fontSize: _estiloTextoAyah.fontSize! * escala);
    final estiloMarcador = _estiloMarcadorAyah.copyWith(
        fontSize: _estiloMarcadorAyah.fontSize! * escala);
    final estiloCabecalho = _estiloCabecalhoSura.copyWith(
        fontSize: _estiloCabecalhoSura.fontSize! * escala);
    final estiloBasmallahEscalado =
        _estiloBasmallah.copyWith(fontSize: _estiloBasmallah.fontSize! * escala);

    final linhasWidgets = <Widget>[];
    final linhasEhTitulo = <bool>[];
    for (final linha in pagina) {
      if (linha is LinhaTituloSura) {
        surahAtual = linha.surah;
        final sura = QuranService.porNumero(linha.surah);
        linhasWidgets
            .add(_linhaCabecalho(sura?.nomeArabe ?? "", estiloCabecalho));
        linhasEhTitulo.add(true);
      } else if (linha is LinhaBasmallah) {
        linhasWidgets.add(_linhaBasmallah(estiloBasmallahEscalado));
        linhasEhTitulo.add(false);
      } else if (linha is LinhaAyah) {
        linhasWidgets.add(
          _linhaAyahWidget(linha, surahAtual, estiloTexto, estiloMarcador),
        );
        linhasEhTitulo.add(false);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          if (juzNovo != null) _bannerJuz(juzNovo),
          for (var i = 0; i < linhasWidgets.length; i++)
            Expanded(
              child: linhasEhTitulo[i]
                  ? Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFD4AF37),
                          width: 1.5,
                        ),
                      ),
                      child: linhasWidgets[i],
                    )
                  : Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFDCD2B0), width: 1),
                        ),
                      ),
                      child: linhasWidgets[i],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _bannerJuz(int juz) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          "Juz $juz",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _linhaCabecalho(String nomeArabe, TextStyle estilo) {
    return Center(
      child: Text(nomeArabe, textDirection: TextDirection.rtl, style: estilo),
    );
  }

  Widget _linhaBasmallah(TextStyle estilo) {
    return Center(
      child: Text(
        IndopakMushafService.basmallah,
        textDirection: TextDirection.rtl,
        style: estilo,
      ),
    );
  }

  Widget _linhaAyahWidget(
    LinhaAyah linha,
    int surahAtual,
    TextStyle estiloTexto,
    TextStyle estiloMarcador,
  ) {
    return Center(
      child: Text.rich(
        TextSpan(
          children: [
            for (final p in linha.palavras) ...[
              TextSpan(text: "${p.texto} ", style: estiloTexto),
              if (p.fimDeAyah)
                TextSpan(
                  text: " ${_marcadorAyah(p.ayah)} ",
                  style: estiloMarcador,
                  recognizer: _recognizerPara(p, surahAtual),
                ),
            ],
          ],
        ),
        textDirection: TextDirection.rtl,
      ),
    );
  }
}
