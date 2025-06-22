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
  late Future<List<Obrigado>> _obrigadosFuture;

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
            MaterialPageRoute(builder: (context) => const CadastroObrigadoScreen()),
          );
          _carregarObrigados();
        },
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Obrigado>>(
        future: _obrigadosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum cliente cadastrado.'));
          } else {
            final obrigados = snapshot.data!;
            return ListView.builder(
              itemCount: obrigados.length,
              itemBuilder: (context, index) {
                final obrigado = obrigados[index];
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
            );
          }
        },
      ),
    );
  }
}