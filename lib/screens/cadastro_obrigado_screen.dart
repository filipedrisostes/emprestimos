import 'package:flutter/material.dart';
import 'package:emprestimos/dao/obrigado_dao.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/models/obrigado.dart';

class CadastroObrigadoScreen extends StatefulWidget {
  final Obrigado? obrigado;

  const CadastroObrigadoScreen({
    super.key,
    this.obrigado,
  });

  @override
  _CadastroObrigadoScreenState createState() => _CadastroObrigadoScreenState();
}

class _CadastroObrigadoScreenState extends State<CadastroObrigadoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _zapController = TextEditingController();
  final _nomeFocusNode = FocusNode();
  final _zapFocusNode = FocusNode();

  final dbHelper = DatabaseHelper.instance;
  late ObrigadoDao obrigadoDao;

  @override
  void initState() {
    super.initState();
    obrigadoDao = ObrigadoDao(dbHelper);
    
    // Se estiver editando, preenche os campos com os valores existentes
    if (widget.obrigado != null) {
      _nomeController.text = widget.obrigado!.nome;
      _zapController.text = widget.obrigado!.zap;
    }
  }

  @override
  void dispose() {
    _nomeFocusNode.dispose();
    _zapFocusNode.dispose();
    super.dispose();
  }

  Future<void> _salvarObrigado() async {
    if (_formKey.currentState!.validate()) {
      if (widget.obrigado == null) {
        // Novo cadastro
        final novoObrigado = Obrigado(
          nome: _nomeController.text,
          zap: _zapController.text,
        );
        await obrigadoDao.insertObrigado(novoObrigado);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Obrigado cadastrado com sucesso!')),
        );
      } else {
        // Edição
        final obrigadoAtualizado = Obrigado(
          id: widget.obrigado!.id,
          nome: _nomeController.text,
          zap: _zapController.text,
        );
        await obrigadoDao.updateObrigado(obrigadoAtualizado);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Obrigado atualizado com sucesso!')),
        );
      }
      
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.obrigado == null 
            ? 'Cadastrar Obrigado' 
            : 'Editar Obrigado'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nomeController,
                focusNode: _nomeFocusNode,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o nome';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_zapFocusNode);
                },
              ),
              TextFormField(
                controller: _zapController,
                focusNode: _zapFocusNode,
                decoration: const InputDecoration(labelText: 'WhatsApp'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o WhatsApp';
                  }
                  return null;
                },
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_nomeFocusNode);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _salvarObrigado,
                child: Text(widget.obrigado == null ? 'Salvar' : 'Atualizar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}