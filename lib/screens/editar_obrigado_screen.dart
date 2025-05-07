import 'package:emprestimos/dao/obrigado_dao.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/models/obrigado.dart';
import 'package:flutter/material.dart';

class EditarObrigadoScreen extends StatefulWidget {
  final Obrigado obrigado;

  const EditarObrigadoScreen({super.key, required this.obrigado});

  @override
  State<EditarObrigadoScreen> createState() => _EditarObrigadoScreenState();
}

class _EditarObrigadoScreenState extends State<EditarObrigadoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _zapController = TextEditingController();
  final _mensagemController = TextEditingController();
  late final ObrigadoDao _obrigadoDao;

  @override
  void initState() {
    super.initState();
    _obrigadoDao = ObrigadoDao(DatabaseHelper.instance);

    // Preencher os campos com os dados existentes
    _nomeController.text = widget.obrigado.nome;
    _zapController.text = widget.obrigado.zap;
    _mensagemController.text = widget.obrigado.mensagemPersonalizada ?? '';
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _zapController.dispose();
    _mensagemController.dispose();
    super.dispose();
  }

  Future<void> _salvarAlteracoes() async {
    if (_formKey.currentState!.validate()) {
      final atualizado = Obrigado(
        id: widget.obrigado.id,
        nome: _nomeController.text,
        zap: _zapController.text,
        mensagemPersonalizada: _mensagemController.text,
      );

      await _obrigadoDao.updateObrigado(atualizado);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Obrigado atualizado com sucesso!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Obrigado')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (value) => value == null || value.isEmpty ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _zapController,
                decoration: const InputDecoration(labelText: 'WhatsApp'),
                validator: (value) => value == null || value.isEmpty ? 'Informe o WhatsApp' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mensagemController,
                decoration: const InputDecoration(labelText: 'Mensagem personalizada'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _salvarAlteracoes,
                child: const Text('Salvar alterações'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
