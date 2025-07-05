import 'package:emprestimos/screens/detalhes_obrigado_screen.dart';
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
  List<Obrigado> _todosObrigados = [];
  List<Obrigado> _obrigadosFiltrados = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarObrigados();
    _searchController.addListener(_filtrarObrigados);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _carregarObrigados() async {
    setState(() => _isLoading = true);
    try {
      final obrigados = await _obrigadoDao.getAllObrigados();
      setState(() {
        _todosObrigados = obrigados;
        _obrigadosFiltrados = obrigados;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar clientes: ${e.toString()}')),
      );
    }
  }

  void _filtrarObrigados() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _obrigadosFiltrados = _todosObrigados.where((obrigado) {
        return obrigado.nome.toLowerCase().contains(query) ||
               obrigado.zap.toLowerCase().contains(query);
      }).toList();
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
            MaterialPageRoute(builder: (context) => const CadastroObrigadoScreen()),
          );
          _carregarObrigados();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar cliente...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _obrigadosFiltrados.isEmpty
                    ? const Center(child: Text('Nenhum cliente encontrado.'))
                    : ListView.builder(
                        itemCount: _obrigadosFiltrados.length,
                        itemBuilder: (context, index) {
                          final obrigado = _obrigadosFiltrados[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              title: Text(obrigado.nome),
                              subtitle: Text('WhatsApp: ${obrigado.zap}'),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DetalhesObrigadoScreen(obrigado: obrigado),
                                  ),
                                );
                              },
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
                                          builder: (_) => EditarObrigadoScreen(obrigado: obrigado),
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
                      ),
          ),
        ],
      ),
    );
  }
}