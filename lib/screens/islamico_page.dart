import 'package:flutter/material.dart';
import 'quran_page.dart';
import 'duas_page.dart';
import 'hadith_page.dart';

/// Página "Islâmico" — Alcorão (árabe e português no mesmo separador),
/// Duas e Hadith em 3 separadores.
/// Vive dentro do PageView principal, por isso não tem AppBar
/// própria (usa a barra do topo da Início).
class IslamicoPage extends StatelessWidget {
  const IslamicoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF0B3D2E),
            child: const TabBar(
              indicatorColor: Color(0xFFD4AF37),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: [
                Tab(text: "Alcorão"),
                Tab(text: "Duas"),
                Tab(text: "Hadith"),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                QuranPage(),
                DuasPage(),
                HadithPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
