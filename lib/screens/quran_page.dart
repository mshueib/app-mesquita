import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../services/local_storage_service.dart';
import '../services/quran_service.dart';
import 'quran_marcadores_page.dart';
import 'quran_pt_page.dart';

const Color _verde = Color(0xFF0B3D2E);
const Color _dourado = Color(0xFFD4AF37);
const Color _verdeClaro = Color(0xFFE6F2ED);

enum _Idioma { arabe, portugues }

enum _ListaArabe { suras, juz }

/// Alcorão — Mushaf árabe (13 linhas, PDF por juz) e tradução em
/// português, no mesmo ecrã com um seletor no topo. Vive dentro do
/// separador "Islâmico" (sem AppBar própria).
class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  final TextEditingController _pesquisaController = TextEditingController();

  _Idioma _idioma = _Idioma.arabe;
  _ListaArabe _listaArabe = _ListaArabe.suras;
  String _pesquisa = "";

  Map<String, dynamic>? _ultimaLeitura;
  int? _ultimaPaginaPt;
  Set<int> _descarregados = {};

  @override
  void initState() {
    super.initState();
    _verificarEstado();
    _pesquisaController.addListener(() {
      setState(() => _pesquisa = _pesquisaController.text.trim());
    });
    // Actualiza os ícones de "offline" à medida que o "Descarregar tudo"
    // avança de juz em juz.
    QuranService.downloadTudoJuz.addListener(_verificarEstado);
  }

  @override
  void dispose() {
    QuranService.downloadTudoJuz.removeListener(_verificarEstado);
    _pesquisaController.dispose();
    super.dispose();
  }

  Future<void> _verificarEstado() async {
    final ultimaArabe = await QuranService.obterUltimaLeitura();
    final ultimaPt = await LocalStorageService.carregarUltimaPaginaQuranPt();
    final descarregados = await QuranService.juzesDescarregados();
    if (!mounted) return;
    setState(() {
      _ultimaLeitura = ultimaArabe;
      _ultimaPaginaPt = ultimaPt;
      _descarregados = descarregados;
    });
  }

  void _abrir(Widget pagina) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => pagina))
        .then((_) => _verificarEstado());
  }

  void _abrirJuz(int juz, {int pagina = 1}) =>
      _abrir(JuzReaderPage(juz: juz, paginaInicial: pagina));

  void _abrirSura(SurahInfo sura) {
    if (_idioma == _Idioma.arabe) {
      _abrirJuz(sura.juzInicial, pagina: QuranService.paginaDaSuraNoJuz(sura));
    } else {
      _abrir(QuranPtReaderPage(paginaInicial: paginaPtDaSura(sura.numero)));
    }
  }

  Future<void> _descarregarTudo() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Descarregar todo o Alcorão?"),
        content: Text(
          "Vão ser descarregados os "
          "${QuranService.totalJuz - _descarregados.length} juz em falta "
          "(até ~42 MB). Recomenda-se usar Wi-Fi.\n\n"
          "Depois disso, o Alcorão fica disponível sem internet.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Descarregar"),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final falhas = await QuranService.descarregarTudo();
    if (!mounted) return;
    final completo = (await QuranService.juzesDescarregados()).length ==
        QuranService.totalJuz;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(completo
          ? "Alcorão completo descarregado ✅"
          : falhas > 0
              ? "$falhas juz não foram descarregados. Verifique a ligação e tente de novo."
              : "Download interrompido."),
    ));
  }

  Future<void> _confirmarApagar(int juz) async {
    final apagar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Apagar Juz $juz?"),
        content: const Text(
            "O ficheiro será removido do telemóvel. Pode voltar a descarregá-lo quando quiser."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Apagar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (apagar != true) return;
    await QuranService.apagarJuz(juz);
    _verificarEstado();
  }

  List<SurahInfo> get _surasFiltradas {
    final termo = _pesquisa.toLowerCase();
    return QuranService.listarSurahs().where((s) {
      return termo.isEmpty ||
          s.numero.toString() == termo ||
          s.nome.toLowerCase().contains(termo);
    }).toList();
  }

  bool get _mostrarJuz =>
      _idioma == _Idioma.arabe &&
      _listaArabe == _ListaArabe.juz &&
      _pesquisa.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F1EA),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _topo()),
          if (_mostrarJuz) _listaJuz() else _listaSuras(),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  // ---------------- Topo ----------------

  Widget _topo() {
    final arabe = _idioma == _Idioma.arabe;
    final continuar = _cardContinuar();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _seletorIdioma(),
          const SizedBox(height: 14),
          if (continuar != null) ...[
            continuar,
            const SizedBox(height: 12),
          ],
          if (arabe) ...[
            _accoesArabe(),
            _progressoDownloadTudo(),
            const SizedBox(height: 12),
          ],
          _campoPesquisa(),
          if (arabe && _pesquisa.isEmpty) ...[
            const SizedBox(height: 12),
            _seletorListaArabe(),
          ],
          if (!arabe) ...[
            const SizedBox(height: 8),
            const Text(
              "Tradução do significado dos versículos",
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _seletorIdioma() {
    Widget opcao(_Idioma idioma, String texto) {
      final ativo = _idioma == idioma;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _idioma = idioma),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: ativo ? _verde : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ativo ? Colors.white : _verde,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _verde.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          opcao(_Idioma.arabe, "Árabe"),
          opcao(_Idioma.portugues, "Português"),
        ],
      ),
    );
  }

  Widget? _cardContinuar() {
    String? detalhe;
    VoidCallback? abrir;

    final ultima = _ultimaLeitura;
    final ultimaPt = _ultimaPaginaPt;
    if (_idioma == _Idioma.arabe && ultima != null) {
      final juz = ultima["juz"] as int;
      final pagina = ultima["pagina"] as int;
      detalhe = "Juz $juz · página $pagina";
      abrir = () => _abrirJuz(juz, pagina: pagina);
    } else if (_idioma == _Idioma.portugues && ultimaPt != null) {
      detalhe = "Página $ultimaPt";
      abrir = () => _abrir(QuranPtReaderPage(paginaInicial: ultimaPt));
    }
    if (detalhe == null) return null;

    return Material(
      color: _verde,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: abrir,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.menu_book, color: _dourado),
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
                      detalhe,
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
      ),
    );
  }

  Widget _accoesArabe() {
    final completo = _descarregados.length == QuranService.totalJuz;
    return Row(
      children: [
        Expanded(
          child: _botaoAccao(
            icone: Icons.bookmark_outline,
            texto: "Marcadores",
            onTap: () => _abrir(const QuranMarcadoresPage()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _botaoAccao(
            icone: completo ? Icons.offline_pin : Icons.download_outlined,
            texto: completo
                ? "Offline completo"
                : "Offline ${_descarregados.length}/${QuranService.totalJuz}",
            onTap: completo || QuranService.aDescarregarTudo
                ? null
                : _descarregarTudo,
          ),
        ),
      ],
    );
  }

  Widget _botaoAccao({
    required IconData icone,
    required String texto,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _verde.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: 18, color: _verde),
              const SizedBox(width: 6),
              Text(
                texto,
                style: const TextStyle(
                  color: _verde,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressoDownloadTudo() {
    return ValueListenableBuilder<int?>(
      valueListenable: QuranService.downloadTudoJuz,
      builder: (context, juzAtual, _) {
        if (juzAtual == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<double>(
                  valueListenable: QuranService.downloadTudoProgresso,
                  builder: (context, progresso, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "A descarregar Juz $juzAtual de ${QuranService.totalJuz} · ${(progresso * 100).round()}%",
                        style: const TextStyle(fontSize: 12, color: _verde),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: progresso,
                        color: _verde,
                        backgroundColor: _verdeClaro,
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: QuranService.cancelarDownloadTudo,
                child: const Text("Parar"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _campoPesquisa() {
    final borda = OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: _verde.withValues(alpha: 0.25)),
    );
    return TextField(
      controller: _pesquisaController,
      decoration: InputDecoration(
        hintText: "Pesquisar sura (nome ou número)",
        prefixIcon: const Icon(Icons.search, color: _verde),
        suffixIcon: _pesquisa.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear, color: Colors.black45),
                onPressed: _pesquisaController.clear,
              ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: borda,
        enabledBorder: borda,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: _dourado, width: 2),
        ),
      ),
    );
  }

  Widget _seletorListaArabe() {
    Widget chip(_ListaArabe lista, String texto) {
      final ativo = _listaArabe == lista;
      return ChoiceChip(
        label: Text(texto),
        selected: ativo,
        onSelected: (_) => setState(() => _listaArabe = lista),
        selectedColor: _verde,
        backgroundColor: Colors.white,
        showCheckmark: false,
        side: BorderSide(color: _verde.withValues(alpha: 0.25)),
        labelStyle: TextStyle(
          color: ativo ? Colors.white : _verde,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Row(
      children: [
        chip(_ListaArabe.suras, "Suras"),
        const SizedBox(width: 8),
        chip(_ListaArabe.juz, "Juz"),
      ],
    );
  }

  // ---------------- Listas ----------------

  Widget _listaSuras() {
    final suras = _surasFiltradas;
    if (suras.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              "Nenhuma sura encontrada.",
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ),
      );
    }

    final arabe = _idioma == _Idioma.arabe;
    return SliverList.separated(
      itemCount: suras.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (context, index) {
        final sura = suras[index];
        final subtitulo = arabe
            ? "Juz ${sura.juzInicial} · página ${QuranService.paginaDaSuraNoJuz(sura)}"
            : "Página ${paginaPtDaSura(sura.numero)}";
        final offline = arabe && _descarregados.contains(sura.juzInicial);
        return ListTile(
          leading: _numero(sura.numero),
          title: Text(
            sura.nome,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(subtitulo),
          trailing: offline
              ? const Icon(Icons.offline_pin, size: 18, color: _verde)
              : const Icon(Icons.chevron_right),
          onTap: () => _abrirSura(sura),
        );
      },
    );
  }

  Widget _listaJuz() {
    return SliverList.separated(
      itemCount: QuranService.totalJuz,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (context, index) {
        final juz = index + 1;
        final descarregado = _descarregados.contains(juz);
        return ListTile(
          leading: _numero(juz),
          title: Text(
            "Juz $juz",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(descarregado
              ? "Disponível offline · toque longo para apagar"
              : "Toque para descarregar (~1,5 MB)"),
          trailing: Icon(
            descarregado ? Icons.offline_pin : Icons.download_outlined,
            size: 20,
            color: descarregado ? _verde : Colors.black38,
          ),
          onTap: () => _abrirJuz(juz),
          onLongPress: descarregado ? () => _confirmarApagar(juz) : null,
        );
      },
    );
  }

  Widget _numero(int n) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _verdeClaro,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "$n",
        style: const TextStyle(color: _verde, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Leitor de um juz em PDF. Se o ficheiro ainda não existir no
/// telemóvel, descarrega-o primeiro (com barra de progresso).
class JuzReaderPage extends StatefulWidget {
  final int juz;
  final int paginaInicial;

  const JuzReaderPage({
    super.key,
    required this.juz,
    this.paginaInicial = 1,
  });

  @override
  State<JuzReaderPage> createState() => _JuzReaderPageState();
}

class _JuzReaderPageState extends State<JuzReaderPage> {
  PdfController? _controller;
  double? _progresso;
  String? _erro;
  int _paginaAtual = 1;
  int? _totalPaginas;

  @override
  void initState() {
    super.initState();
    _paginaAtual = widget.paginaInicial;
    _preparar();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _preparar() async {
    // Só é chamado de novo a partir do ecrã de erro, quando o PdfView já
    // não está montado — por isso é seguro descartar o controlador aqui.
    _controller?.dispose();
    _controller = null;
    setState(() {
      _erro = null;
      _progresso = null;
    });

    try {
      var ficheiro = await QuranService.ficheiroJuz(widget.juz);
      if (!await ficheiro.exists()) {
        setState(() => _progresso = 0);
        ficheiro = await QuranService.descarregarJuz(
          widget.juz,
          onProgresso: (p) {
            if (mounted) setState(() => _progresso = p);
          },
        );
      }
      if (!mounted) return;
      setState(() {
        _progresso = null;
        _controller = PdfController(
          document: PdfDocument.openFile(ficheiro.path),
          initialPage: widget.paginaInicial,
        );
      });
      QuranService.registarUltimaLeitura(widget.juz, _paginaAtual);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _progresso = null;
        _erro = "Não foi possível descarregar o Juz ${widget.juz}.\n"
            "Verifique a sua ligação à internet e tente novamente.";
      });
    }
  }

  Future<void> _adicionarMarcador() async {
    final nomeController = TextEditingController(
      text: "Juz ${widget.juz} · página $_paginaAtual",
    );
    final nome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Guardar marcador"),
        content: TextField(
          controller: nomeController,
          autofocus: true,
          decoration: const InputDecoration(labelText: "Nome do marcador"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nomeController.text.trim()),
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
    nomeController.dispose();
    if (nome == null) return;

    await QuranService.salvarMarcador(QuranMarcador(
      nome: nome.isEmpty ? "Juz ${widget.juz} · página $_paginaAtual" : nome,
      juz: widget.juz,
      pagina: _paginaAtual,
      criadoEm: DateTime.now(),
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Marcador guardado")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalPaginas;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _verde,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          total == null
              ? "Juz ${widget.juz}"
              : "Juz ${widget.juz} · $_paginaAtual/$total",
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (_controller != null)
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined),
              tooltip: "Guardar marcador",
              onPressed: _adicionarMarcador,
            ),
        ],
      ),
      body: _corpo(),
    );
  }

  Widget _corpo() {
    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.black38),
              const SizedBox(height: 12),
              Text(_erro!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _preparar,
                style: ElevatedButton.styleFrom(backgroundColor: _verde),
                child: const Text(
                  "Tentar novamente",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_progresso != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("A descarregar o Juz ${widget.juz}…"),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _progresso! > 0 ? _progresso : null,
                color: _verde,
                backgroundColor: const Color(0xFFE6F2ED),
              ),
              const SizedBox(height: 8),
              Text("${(_progresso! * 100).round()}%"),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator(color: _verde));
    }

    // reverse: o Mushaf lê-se da direita para a esquerda — a página
    // seguinte fica à esquerda, como num livro árabe.
    return PdfView(
      controller: controller,
      reverse: true,
      backgroundDecoration: const BoxDecoration(color: Colors.white),
      onDocumentLoaded: (doc) {
        setState(() => _totalPaginas = doc.pagesCount);
        // Um marcador antigo pode apontar para além do fim do PDF.
        if (widget.paginaInicial > doc.pagesCount) {
          controller.jumpToPage(1);
        }
      },
      onDocumentError: (_) async {
        // PDF corrompido: apaga-o para que "Tentar novamente" o volte a
        // descarregar do zero.
        await QuranService.apagarJuz(widget.juz);
        if (!mounted) return;
        setState(() {
          _erro = "O ficheiro do Juz ${widget.juz} está danificado.\n"
              "Toque em \"Tentar novamente\" para o descarregar outra vez.";
        });
      },
      onPageChanged: (pagina) {
        setState(() => _paginaAtual = pagina);
        QuranService.registarUltimaLeitura(widget.juz, pagina);
      },
    );
  }
}
