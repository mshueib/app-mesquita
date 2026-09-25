import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/mesquita_registo_service.dart';
import 'admin_login_page.dart';

/// Protege [PedidosPage] com o PIN de super-admin (app/super_admin_pin),
/// reutilizando o mesmo AdminLoginPage usado no admin de cada mesquita.
class SuperAdminGatewayPage extends StatefulWidget {
  const SuperAdminGatewayPage({super.key});

  @override
  State<SuperAdminGatewayPage> createState() => _SuperAdminGatewayPageState();
}

class _SuperAdminGatewayPageState extends State<SuperAdminGatewayPage> {
  bool _autenticado = false;

  @override
  Widget build(BuildContext context) {
    if (_autenticado) return const PedidosPage();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3D2E),
        title: const Text("Super Admin", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AdminLoginPage(
        titulo: "Acesso Super Admin",
        loginFn: AuthService.loginSuperAdmin,
        onSuccess: () => setState(() => _autenticado = true),
      ),
    );
  }
}

class PedidosPage extends StatefulWidget {
  const PedidosPage({super.key});

  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _pendentes = [];
  List<Map<String, dynamic>> _aprovados = [];
  List<Map<String, dynamic>> _rejeitados = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _carregar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final pendentes = await MesquitaRegistoService.listarPendentes();
      final aprovados = await MesquitaRegistoService.listarAprovadas();
      final rejeitados = await MesquitaRegistoService.listarRejeitados();

      if (!mounted) return;
      setState(() {
        _pendentes = pendentes;
        _aprovados = aprovados;
        _rejeitados = rejeitados;
        _carregando = false;
      });
    } catch (e) {
      // Sem isto, um erro (ex: permissão recusada pelas regras da base de
      // dados) deixava o ecrã a carregar para sempre.
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = "Não foi possível carregar os pedidos.\n($e)";
      });
    }
  }

  Future<void> _aprovar(Map<String, dynamic> pedido) async {
    final mesquita = Map<String, dynamic>.from(pedido['mesquita'] ?? {});

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Aprovar Mesquita"),
        content: Text(
          "Aprovar o registo de \"${mesquita['nome'] ?? ''}\"?\n\n"
          "A mesquita passará a aparecer na pesquisa e o requerente poderá "
          "gerir a mesquita entrando com a mesma conta Google usada no registo.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B3D2E)),
            child: const Text("Aprovar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await MesquitaRegistoService.aprovar(pedido['id'], pedido);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${mesquita['nome'] ?? 'Mesquita'} aprovada com sucesso!"),
          backgroundColor: Colors.green,
        ),
      );
      _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao aprovar: $e"), backgroundColor: Colors.red),
      );
    }
  }

  /// Remover é irreversível (horários, avisos, tudo) — por isso pede que
  /// se escreva o nome da mesquita, para não acontecer por engano.
  Future<void> _remover(Map<String, dynamic> m) async {
    final nome = (m['nome'] ?? "").toString();
    final confirmacaoCtrl = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialogo) {
          final nomeCerto = confirmacaoCtrl.text.trim().toLowerCase() ==
              nome.trim().toLowerCase();
          return AlertDialog(
            title: const Text("Remover mesquita"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "A \"$nome\" vai deixar de aparecer na app e todos os "
                  "horários e avisos serão apagados. Isto não pode ser "
                  "desfeito.\n\nPara confirmar, escreva o nome da mesquita:",
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmacaoCtrl,
                  autofocus: true,
                  onChanged: (_) => setStateDialogo(() {}),
                  decoration: InputDecoration(
                    hintText: nome,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: nomeCerto ? () => Navigator.pop(ctx, true) : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Remover",
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
    confirmacaoCtrl.dispose();
    if (confirmar != true) return;

    try {
      await MesquitaRegistoService.remover(m['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("\"$nome\" foi removida"),
            backgroundColor: Colors.orange),
      );
      _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Erro ao remover: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejeitar(Map<String, dynamic> pedido) async {
    final motivoCtrl = TextEditingController();
    final mesquita = Map<String, dynamic>.from(pedido['mesquita'] ?? {});

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Rejeitar Pedido"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Rejeitar: ${mesquita['nome'] ?? ''}"),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: "Motivo (opcional)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Rejeitar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await MesquitaRegistoService.rejeitar(pedido['id'], motivo: motivoCtrl.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pedido rejeitado"), backgroundColor: Colors.orange),
      );
      _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao rejeitar: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Widget _cartao(Map<String, dynamic> p,
      {bool pendente = false, bool aprovada = false}) {
    final requerente = Map<String, dynamic>.from(p['requerente'] ?? {});
    final localizacao = Map<String, dynamic>.from(p['localizacao'] ?? {});
    final mesquita = Map<String, dynamic>.from(p['mesquita'] ?? {});

    final nome = mesquita['nome'] ?? p['nome'] ?? "";
    final cidade = localizacao['cidade'] ?? p['cidade'] ?? "";
    final pais = localizacao['pais'] ?? p['pais'] ?? "";

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B3D2E).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.mosque, color: Color(0xFF0B3D2E), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nome,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        "$cidade${pais.toString().isNotEmpty ? ', $pais' : ''}",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (requerente.isNotEmpty) ...[
              _info(Icons.person_outline,
                  "${requerente['nome'] ?? ''} — ${requerente['cargo'] ?? ''}"),
              _info(Icons.email_outlined, requerente['email'] ?? ""),
              _info(Icons.phone_outlined, requerente['telefone'] ?? ""),
            ],
            if (mesquita['contacto'] != null &&
                mesquita['contacto'].toString().isNotEmpty)
              _info(Icons.chat_outlined, "Contacto da mesquita: ${mesquita['contacto']}"),
            if (p['motivo_rejeicao'] != null &&
                p['motivo_rejeicao'].toString().isNotEmpty)
              _info(Icons.info_outline, "Motivo: ${p['motivo_rejeicao']}"),
            if (pendente) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rejeitar(p),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child:
                          const Text("Rejeitar", style: TextStyle(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _aprovar(p),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B3D2E),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Aprovar",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
            if (aprovada) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _remover(p),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text("Remover mesquita",
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _info(IconData icon, String texto) {
    if (texto.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(texto, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _lista(List<Map<String, dynamic>> lista,
      {bool pendente = false, bool aprovada = false}) {
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text("Sem pedidos", style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: lista.length,
      itemBuilder: (_, i) =>
          _cartao(lista[i], pendente: pendente, aprovada: aprovada),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3D2E),
        foregroundColor: Colors.white,
        title: const Text("Pedidos de Registo"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _carregar),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD4AF37),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Pendentes"),
                  if (_pendentes.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${_pendentes.length}",
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: "Aprovados"),
            const Tab(text: "Rejeitados"),
          ],
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.black38),
                        const SizedBox(height: 12),
                        Text(_erro!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _carregar,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0B3D2E)),
                          child: const Text("Tentar novamente",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
              controller: _tabController,
              children: [
                _lista(_pendentes, pendente: true),
                _lista(_aprovados, aprovada: true),
                _lista(_rejeitados),
              ],
            ),
    );
  }
}
