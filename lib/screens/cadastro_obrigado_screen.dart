import 'package:flutter/material.dart';
import 'package:emprestimos/contact_helper.dart';
import 'package:emprestimos/dao/obrigado_dao.dart';
import 'package:emprestimos/models/obrigado.dart';
import 'package:emprestimos/database_helper.dart';

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
  final _searchController = TextEditingController();
  final _mensagemController = TextEditingController(); // ✅ Novo Controller para mensagem personalizada
  
  List<Map<String, String>> _contacts = [];
  List<Map<String, String>> _filteredContacts = [];
  final List<Map<String, String>> _selectedContacts = [];
  bool _showManualForm = false;
  bool _isLoading = false;
  bool _isSaving = false;
  final ObrigadoDao _obrigadoDao = ObrigadoDao(DatabaseHelper.instance);

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _zapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
  setState(() => _isLoading = true);
  try {
    final contacts = await ContactHelper.getContactsSimplified();
    setState(() {
      _contacts = contacts.where((c) => c['phone']!.isNotEmpty).toList();
      _filteredContacts = _contacts;
    });
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao acessar contatos: ${e.toString()}')),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContacts = _contacts.where((contact) {
        final name = contact['name']?.toLowerCase() ?? '';
        final phone = contact['phone']?.toLowerCase() ?? '';
        return name.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  Widget _buildManualForm() {
    return Form(
      key: _formKey,
      child: Column(
  children: [
    // Campo Nome
    TextFormField(
      controller: _nomeController,
      decoration: const InputDecoration(
        labelText: 'Nome',
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) => value?.isEmpty ?? true ? 'Informe o nome' : null,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    ),

    const SizedBox(height: 16),

    // Campo WhatsApp
    TextFormField(
      controller: _zapController,
      decoration: const InputDecoration(
        labelText: 'WhatsApp',
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
        hintText: 'DDD + número ou código internacional',
      ),
      keyboardType: TextInputType.phone,
      validator: (value) {
        if (value?.isEmpty ?? true) return null;
        if (!RegExp(r'^(\+?[0-9]{11,14}|[0-9]{2}[0-9]{8,9})$').hasMatch(value!)) {
          return 'Formato: (DDD) + número ou +código';
        }
      },
      autovalidateMode: AutovalidateMode.onUserInteraction,
    ),
    const SizedBox(height: 16),
    // ✅ Novo campo de mensagem personalizada
    TextFormField(
      controller: _mensagemController,
      decoration: const InputDecoration(
        labelText: 'Mensagem personalizada (opcional)',
        border: OutlineInputBorder(),
        hintText: "Use # para o nome do cliente e % para o valor",
      ),
      maxLines: 3,
    ),
    const SizedBox(height: 24),

    // Botão de Salvar
    ElevatedButton(
      onPressed: _isSaving ? null : _saveManualContact,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: Colors.blue[700],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isSaving
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Text(
              'Salvar Obrigado',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    ),
  ],
),
    );
  }

  Widget _buildImportForm() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_contacts.isEmpty) {
      return Column(
        children: [
          const Text('Nenhum contato encontrado'),
          TextButton(
            onPressed: _loadContacts,
            child: const Text('Tentar novamente'),
          ),
        ],
      );
    }

    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: 'Buscar contatos',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Selecione os contatos para cadastrar:'),
        const SizedBox(height: 8),
        SizedBox(
          height: 300,
          child: ListView.builder(
            itemCount: _filteredContacts.length,
            itemBuilder: (context, index) {
              final contact = _filteredContacts[index];
              return CheckboxListTile(
                title: Text(contact['name'] ?? ''),
                subtitle: Text(contact['phone'] ?? ''),
                value: _selectedContacts.contains(contact),
                onChanged: (bool? value) => setState(() {
                  value == true
                      ? _selectedContacts.add(contact)
                      : _selectedContacts.remove(contact);
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _selectedContacts.isEmpty ? null : _saveImportedContacts,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
          child: const Text('Cadastrar Selecionados'),
        ),
      ],
    );
  }

  Future<void> _saveManualContact() async {
  if (_formKey.currentState!.validate()) {
    setState(() => _isSaving = true);
    
    try {
      await _obrigadoDao.insertObrigado(
        Obrigado(
          nome: _nomeController.text,
          zap: _formatNumber(_zapController.text),
          mensagemPersonalizada: _mensagemController.text.isEmpty ? null : _mensagemController.text, // ✅ Salva se houver
        ),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente cadastrado com sucesso!')),
      );
      
      _nomeController.clear();
      _zapController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }
}

  Future<void> _saveImportedContacts() async {
    try {
      for (var contact in _selectedContacts) {
        await _obrigadoDao.insertObrigado(
          Obrigado(
            nome: contact['name'] ?? '',
            zap: _formatNumber(contact['phone'] ?? ''),
          ),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedContacts.length} contatos cadastrados com sucesso!'),
        ),
      );

      setState(() => _selectedContacts.clear());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao cadastrar: ${e.toString()}')),
      );
    }
  }

  String _formatNumber(String number) {
    return number.replaceAll(RegExp(r'[^0-9]'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastrar Cliente'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Botões de alternância
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showManualForm = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_showManualForm
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300],
                    ),
                    child: Text(
                      'Importar da Agenda',
                      style: TextStyle(
                        color: !_showManualForm ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showManualForm = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showManualForm
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300],
                    ),
                    child: Text(
                      'Cadastro Manual',
                      style: TextStyle(
                        color: _showManualForm ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Formulário condicional
            _showManualForm ? _buildManualForm() : _buildImportForm(),
          ],
        ),
      ),
    );
  }
}