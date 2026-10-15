import 'detalhes_obrigado_screen.dart';
import 'package:flutter/material.dart';
import 'package:emprestimos/models/obrigado.dart';
import 'package:emprestimos/dao/obrigado_dao.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/screens/cadastro_obrigado_screen.dart';
import 'package:emprestimos/screens/editar_obrigado_screen.dart';

class ListaObrigadosScreen extends StatefulWidget {
  const ListaObrigadosScreen({super.key});

  @override
  State<ListaObrigadosScreen> createState() => _ListaObrigadosScreenState();
}

class _ListaObrigadosScreenState extends State<ListaObrigadosScreen> {
  final ObrigadoDao _obrigadoDao = ObrigadoDao(DatabaseHelper.instance);
  late Future<List<Obrigado>> _obrigadosFuture;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _carregarObrigados();
  }

  void _carregarObrigados() {
    setState(() {
      _obrigadosFuture = _obrigadoDao.getAllObrigados();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Clientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarObrigados,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const CadastroObrigadoScreen()),
          );
          _carregarObrigados();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
                decoration: const InputDecoration(
                    hintText: 'Pesquisar cliente...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder()),
                onChanged: (s) => setState(() => _search = s.toLowerCase()))),
        Expanded(
            child: FutureBuilder<List<Obrigado>>(
          future: _obrigadosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Erro: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Nenhum cliente encontrado.'));
            } else {
              final obrigados = snapshot.data!
                  .where((o) =>
                      o.nome.toLowerCase().contains(_search) ||
                      o.zap.contains(_search))
                  .toList();
              if (obrigados.isEmpty)
                return const Center(child: Text('Nenhum cliente encontrado.'));
              return ListView.builder(
                itemCount: obrigados.length,
                itemBuilder: (context, index) {
                  final obrigado = obrigados[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  DetalhesObrigadoScreen(obrigado: obrigado))),
                      title: Text(obrigado.nome),
                      subtitle: Text('WhatsApp: ${obrigado.zap}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            tooltip: 'Editar',
                            onPressed: () async {
                              final atualizado = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EditarObrigadoScreen(obrigado: obrigado),
                                ),
                              );
                              if (atualizado == true) {
                                _carregarObrigados();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }
          },
        )),
      ]),
    );
  }
}
