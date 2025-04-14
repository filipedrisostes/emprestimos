import 'package:flutter/material.dart';
import 'package:emprestimos/dao/obrigado_dao.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/models/obrigado.dart';
import 'package:emprestimos/screens/cadastro_obrigado_screen.dart';

class ListaObrigadosScreen extends StatefulWidget {
  const ListaObrigadosScreen({super.key});

  @override
  _ListaObrigadosScreenState createState() => _ListaObrigadosScreenState();
}

class _ListaObrigadosScreenState extends State<ListaObrigadosScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  late ObrigadoDao obrigadoDao;
  List<Obrigado> obrigados = [];

  @override
  void initState() {
    super.initState();
    obrigadoDao = ObrigadoDao(dbHelper);
    _carregarObrigados();
  }

  Future<void> _carregarObrigados() async {
    final lista = await obrigadoDao.getAllObrigados();
    setState(() {
      obrigados = lista;
    });
  }

  Future<void> _excluirObrigado(int id) async {
    await obrigadoDao.deleteObrigado(id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Obrigado excluído com sucesso!')),
    );
    _carregarObrigados();
  }

  void _editarObrigado(Obrigado obrigado) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CadastroObrigadoScreen(
          obrigado: obrigado,
        ),
      ),
    );
    
    if (result == true) {
      _carregarObrigados();
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Lista de Obrigados'),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _navigateToAddObrigado(context),
        ),
      ],
    ),
    body: _buildBody(),
  );
}

Widget _buildBody() {
  return obrigados.isEmpty
      ? const Center(child: Text('Nenhum obrigado cadastrado.'))
      : ListView.builder(
          itemCount: obrigados.length,
          itemBuilder: (context, index) {
            final obrigado = obrigados[index];
            return _buildObrigadoItem(obrigado);
          },
        );
}

Widget _buildObrigadoItem(Obrigado obrigado) {
  return Card(
    margin: const EdgeInsets.all(8.0),
    child: ListTile(
      title: Text(obrigado.nome),
      subtitle: Text(obrigado.zap),
      trailing: _buildActionButtons(obrigado),
    ),
  );
}

Widget _buildActionButtons(Obrigado obrigado) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: const Icon(Icons.edit, color: Colors.blue),
        onPressed: () => _editarObrigado(obrigado),
      ),
      IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () => _confirmarExclusao(obrigado.id!),
      ),
    ],
  );
}

Future<void> _navigateToAddObrigado(BuildContext context) async {
  await Future.delayed(Duration.zero); // Adiciona um pequeno atraso
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const CadastroObrigadoScreen(),
    ),
  );
  
  if (result == true) {
    _carregarObrigados();
  }
}

Future<void> _confirmarExclusao(int id) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirmar Exclusão'),
      content: const Text('Tem certeza que deseja excluir este obrigado?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await _excluirObrigado(id);
  }
}
}