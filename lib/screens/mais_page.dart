import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../utils/nav_helper.dart';
import 'admin_login_page.dart';
import 'admin_panel_page.dart';
import 'developer_page.dart';
import 'pedidos_page.dart';
import '../services/mesquita_registo_service.dart';

/// Menu "Mais" — reúne Admin, Super Admin e Sobre numa única aba.
/// Tasbih, Zakat e Qibla vivem como páginas próprias no PageView
/// principal (ver [_secoes] em main.dart), acessíveis por swipe ou
/// pelo botão "Menu Principal" da Início.
class MaisPage extends StatelessWidget {
  final DatabaseReference dbRef;
  final Map<String, dynamic> dados;

  const MaisPage({
    super.key,
    required this.dbRef,
    required this.dados,
  });

  @override
  Widget build(BuildContext context) {
    final itens = <_ItemMenu>[
      _ItemMenu(
        icone: Icons.lock,
        titulo: "Admin",
        subtitulo: "Área restrita",
        onTap: (context) => NavHelper.push(
          context,
          AdminGatewayPage(dbRef: dbRef, dadosAtuais: dados),
        ),
      ),
      _ItemMenu(
        icone: Icons.verified_user_outlined,
        titulo: "Super Admin",
        subtitulo: "Aprovar registos de mesquitas",
        onTap: (context) =>
            NavHelper.push(context, const SuperAdminGatewayPage()),
      ),
      _ItemMenu(
        icone: Icons.info_outline,
        titulo: "Sobre",
        subtitulo: "Sobre a aplicação",
        onTap: (context) => NavHelper.push(
          context,
          const _PageComAppBar(titulo: "Sobre", child: DeveloperPage()),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3D2E),
        title: const Text("Mais", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: itens.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = itens[index];
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF0B3D2E),
                child: Icon(item.icone, color: Colors.white),
              ),
              title: Text(
                item.titulo,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(item.subtitulo),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => item.onTap(context),
            ),
          );
        },
      ),
    );
  }
}

/// [QiblaPage] e [DeveloperPage] foram desenhadas para viver dentro da
/// PageView original (sem AppBar própria, partilhando a barra do topo
/// da Início). Ao serem abertas via Navigator a partir do "Mais",
/// precisam de uma AppBar própria — só para terem botão de voltar —
/// sem alterar a lógica interna de nenhuma das duas.
class _PageComAppBar extends StatelessWidget {
  final String titulo;
  final Widget child;

  const _PageComAppBar({required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3D2E),
        title: Text(titulo, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: child,
    );
  }
}

class _ItemMenu {
  final IconData icone;
  final String titulo;
  final String subtitulo;
  final void Function(BuildContext context) onTap;

  _ItemMenu({
    required this.icone,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });
}

/// Orquestra o acesso administrativo (login → painel), isolado numa
/// página própria para poder ser aberto via Navigator a partir do "Mais".
/// Não altera a lógica interna de [AdminLoginPage] nem de [AdminPanelPage].
class AdminGatewayPage extends StatefulWidget {
  final DatabaseReference dbRef;
  final Map<String, dynamic> dadosAtuais;

  const AdminGatewayPage({
    super.key,
    required this.dbRef,
    required this.dadosAtuais,
  });

  @override
  State<AdminGatewayPage> createState() => _AdminGatewayPageState();
}

class _AdminGatewayPageState extends State<AdminGatewayPage> {
  bool _autenticado = false;

  // Preenchido quando quem entra é o "admin principal" de uma mesquita
  // auto-registada (username/senha) — substitui a mesquita atualmente
  // navegada pela mesquita que este admin efetivamente administra.
  DatabaseReference? _dbRefProprio;
  Map<String, dynamic>? _dadosProprios;

  Future<void> _entrarComoAdminDaMesquita(String uid) async {
    final ref = MesquitaRegistoService.refParaMesquita(uid);
    final snap = await ref.get();

    setState(() {
      _dbRefProprio = ref;
      _dadosProprios =
          snap.exists ? Map<String, dynamic>.from(snap.value as Map) : {};
      _autenticado = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_autenticado) {
      return AdminPanelPage(
        dbRef: _dbRefProprio ?? widget.dbRef,
        dadosAtuais: _dadosProprios ?? widget.dadosAtuais,
        onLogout: () => setState(() {
          _autenticado = false;
          _dbRefProprio = null;
          _dadosProprios = null;
        }),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3D2E),
        title: const Text(
          "Acesso Administrativo",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AdminLoginPage(
        mostrarLoginMesquita: true,
        onSuccessMesquita: _entrarComoAdminDaMesquita,
        onSuccess: () => setState(() => _autenticado = true),
      ),
    );
  }
}
