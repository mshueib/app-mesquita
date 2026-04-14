import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

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

  void _carregar() async {
    final snapshot =
        await FirebaseDatabase.instance.ref("pedidos_registo").get();

    if (!snapshot.exists) {
      setState(() => _carregando = false);
      return;
    }

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    List<Map<String, dynamic>> pendentes = [];
    List<Map<String, dynamic>> aprovados = [];
    List<Map<String, dynamic>> rejeitados = [];

    data.forEach((key, value) {
      final item = Map<String, dynamic>.from(value);
      item['id'] = key;
      switch (item['status']) {
        case 'aprovado':
          aprovados.add(item);
          break;
        case 'rejeitado':
          rejeitados.add(item);
          break;
        default:
          pendentes.add(item);
      }
    });

    // ordenar por timestamp mais recente
    pendentes
        .sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
    aprovados
        .sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
    rejeitados
        .sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

    setState(() {
      _pendentes = pendentes;
      _aprovados = aprovados;
      _rejeitados = rejeitados;
      _carregando = false;
    });
  }

  Future<void> _aprovar(Map<String, dynamic> pedido) async {
    // mostrar dialogo para definir password e ID da mesquita
    final idCtrl = TextEditingController(
      text: pedido['nome'].toString().toLowerCase().replaceAll(' ', '_'),
    );
    final passwordCtrl = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Aprovar Mesquita"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Mesquita: ${pedido['nome']}",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: idCtrl,
              decoration: InputDecoration(
                labelText: "ID da mesquita",
                hintText: "ex: masjid_maputo",
                helperText: "Identificador único, sem espaços",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Password temporária para o admin",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0B3D2E),
            ),
            child: const Text("Aprovar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    if (idCtrl.text.trim().isEmpty || passwordCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Preenche o ID e a password"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final mesquitaId = idCtrl.text.trim();
      final email = pedido['email'];

      // criar nó da mesquita
      await FirebaseDatabase.instance.ref("mesquitas/$mesquitaId").set({
        "nome": pedido['nome'],
        "cidade": pedido['cidade'],
        "pais": pedido['pais'] ?? "",
        "status": "ativo",
        "email_admin": email,
        "fajr_azan": "--:--",
        "fajr_namaz": "--:--",
        "dhuhr_azan": "--:--",
        "dhuhr_namaz": "--:--",
        "asr_azan": "--:--",
        "asr_namaz": "--:--",
        "maghrib_azan": "--:--",
        "maghrib_namaz": "--:--",
        "isha_azan": "--:--",
        "isha_namaz": "--:--",
        "jummah_azan": "--:--",
        "jummah_namaz": "--:--",
        "mes_islamico": "",
        "ano_islamico": "1447",
        "jejum": "1",
        "sehri": "--:--",
        "iftar": "--:--",
        "orador_jummah": "",
        "nissab_valor": "0",
      });

      // guardar credenciais do admin da mesquita
      await FirebaseDatabase.instance.ref("admins_mesquita/$mesquitaId").set({
        "email": email,
        "password": passwordCtrl.text.trim(),
        "mesquita_id": mesquitaId,
        "nome_mesquita": pedido['nome'],
        "ativo": true,
      });

      // actualizar status do pedido
      await FirebaseDatabase.instance
          .ref("pedidos_registo/${pedido['id']}")
          .update({
        "status": "aprovado",
        "mesquita_id": mesquitaId,
        "data_aprovacao": DateTime.now().millisecondsSinceEpoch,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${pedido['nome']} aprovada com sucesso!"),
          backgroundColor: Colors.green,
        ),
      );

      _carregar();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejeitar(Map<String, dynamic> pedido) async {
    final motivoCtrl = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Rejeitar Pedido"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Rejeitar: ${pedido['nome']}"),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: "Motivo (opcional)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
            child:
                const Text("Rejeitar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await FirebaseDatabase.instance
        .ref("pedidos_registo/${pedido['id']}")
        .update({
      "status": "rejeitado",
      "motivo_rejeicao": motivoCtrl.text.trim(),
      "data_rejeicao": DateTime.now().millisecondsSinceEpoch,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Pedido rejeitado"),
        backgroundColor: Colors.orange,
      ),
    );

    _carregar();
  }

  Widget _cartao(Map<String, dynamic> p, {bool pendente = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
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
                  child: const Icon(Icons.mosque,
                      color: Color(0xFF0B3D2E), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['nome'] ?? "",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        "${p['cidade'] ?? ''}${p['pais'] != null && p['pais'].isNotEmpty ? ', ${p['pais']}' : ''}",
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _info(Icons.email_outlined, p['email'] ?? ""),
            _info(Icons.phone_outlined, p['telefone'] ?? ""),
            if (p['mensagem'] != null && p['mensagem'].isNotEmpty)
              _info(Icons.message_outlined, p['mensagem']),
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
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text("Rejeitar",
                          style: TextStyle(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _aprovar(p),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B3D2E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text("Aprovar",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _info(IconData icon, String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lista(List<Map<String, dynamic>> lista, {bool pendente = false}) {
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              "Sem pedidos",
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: lista.length,
      itemBuilder: (_, i) => _cartao(lista[i], pendente: pendente),
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _carregando = true);
              _carregar();
            },
          ),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
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
          : TabBarView(
              controller: _tabController,
              children: [
                _lista(_pendentes, pendente: true),
                _lista(_aprovados),
                _lista(_rejeitados),
              ],
            ),
    );
  }
}
