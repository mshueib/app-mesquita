import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../services/local_storage_service.dart';

const Color _verde = Color(0xFF0B3D2E);

const String _assetPdf = 'assets/quran/alcorao_pt.pdf';

/// Página do PDF onde começa cada sura (índice 0 = sura 1). Gerado a
/// partir dos títulos "CAPÍTULO …" do próprio PDF, que não tem índice.
const List<int> _paginaInicioSura = [
  1, 1, 21, 33, 46, 56, 66, 77, 81, 90, 96, 102, 107, 110, 113, 116, 122, //
  128, 134, 137, 143, 147, 152, 155, 160, 164, 169, 173, 178, 182, 184, //
  186, 187, 192, 195, 197, 199, 203, 206, 209, 213, 216, 218, 221, 223, //
  224, 226, 227, 229, 230, 232, 233, 235, 237, 238, 240, 242, 244, 245, //
  247, 248, 249, 250, 250, 251, 252, 253, 254, 255, 257, 258, 259, 260, //
  261, 262, 263, 264, 265, 266, 267, 268, 269, 270, 271, 271, 272, 273, //
  273, 274, 274, 275, 276, 276, 276, 277, 277, 278, 278, 278, 279, 279, //
  279, 279, 280, 280, 280, 281, 281, 281, 281, 282, 282, 282, 282,
];

/// Página do PDF em português onde começa a sura [numero].
int paginaPtDaSura(int numero) => _paginaInicioSura[numero - 1];

/// Tradução portuguesa do significado dos versículos (PDF embutido na
/// app — funciona sem internet). A lista de suras está em QuranPage.
class QuranPtReaderPage extends StatefulWidget {
  final int paginaInicial;

  const QuranPtReaderPage({super.key, this.paginaInicial = 1});

  @override
  State<QuranPtReaderPage> createState() => _QuranPtReaderPageState();
}

class _QuranPtReaderPageState extends State<QuranPtReaderPage> {
  late final PdfController _controller = PdfController(
    document: PdfDocument.openAsset(_assetPdf),
    initialPage: widget.paginaInicial,
  );
  late int _paginaAtual = widget.paginaInicial;
  int? _totalPaginas;

  @override
  void initState() {
    super.initState();
    LocalStorageService.salvarUltimaPaginaQuranPt(widget.paginaInicial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _verde,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _totalPaginas == null
              ? "Alcorão em Português"
              : "Página $_paginaAtual/$_totalPaginas",
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PdfView(
        controller: _controller,
        scrollDirection: Axis.vertical,
        backgroundDecoration: const BoxDecoration(color: Color(0xFFEEEEEE)),
        onDocumentLoaded: (doc) =>
            setState(() => _totalPaginas = doc.pagesCount),
        onPageChanged: (pagina) {
          setState(() => _paginaAtual = pagina);
          LocalStorageService.salvarUltimaPaginaQuranPt(pagina);
        },
      ),
    );
  }
}
