// database_explorer_screen.dart
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:emprestimos/database_helper.dart';

// Database Explorer Screen - Versão com tratamento para grandes resultados
class DatabaseExplorerScreen extends StatefulWidget {
  const DatabaseExplorerScreen({super.key});

  @override
  State<DatabaseExplorerScreen> createState() => _DatabaseExplorerScreenState();
}

class _DatabaseExplorerScreenState extends State<DatabaseExplorerScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  List<String> _tables = [];
  String? _selectedTable;
  List<Map<String, dynamic>> _tableData = [];
  List<String> _columns = [];
  final TextEditingController _sqlController = TextEditingController();
  String _sqlResult = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  @override
  void dispose() {
    _sqlController.dispose();
    super.dispose();
  }

  Future<void> _loadTables() async {
    setState(() => _isLoading = true);
    try {
      final db = await dbHelper.database;
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      setState(() {
        _tables = tables.map((t) => t['name'] as String).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erro ao carregar tabelas: ${e.toString()}');
    }
  }

  Future<void> _loadTableData(String tableName) async {
    setState(() {
      _isLoading = true;
      _selectedTable = tableName;
      _sqlResult = '';
    });
    try {
      final db = await dbHelper.database;
      final data = await db.query(tableName);
      if (data.isNotEmpty) {
        setState(() {
          _tableData = data;
          _columns = data.first.keys.toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _tableData = [];
          _columns = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erro ao carregar dados: ${e.toString()}');
    }
  }

  Future<void> _executeSql() async {
    if (_sqlController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final db = await dbHelper.database;
      final result = await db.rawQuery(_sqlController.text);
      
      setState(() {
        _sqlResult = 'Resultado: ${result.length} linhas\n\n';
        if (result.isNotEmpty) {
          _sqlResult += 'Colunas: ${result.first.keys.join(', ')}\n\n';
          _sqlResult += result.map((e) => e.toString()).join('\n\n');
        }
        _isLoading = false;
      });
      
      if (_selectedTable != null && 
          _sqlController.text.toLowerCase().contains(_selectedTable!.toLowerCase())) {
        await _loadTableData(_selectedTable!);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erro na SQL: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorador do Banco'),
      ),
      body: Column(
        children: [
          // Seção de tabelas
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Text('Tabelas: '),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedTable,
                    hint: const Text('Selecione uma tabela'),
                    items: _tables.map((table) {
                      return DropdownMenuItem<String>(
                        value: table,
                        child: Text(table),
                      );
                    }).toList(),
                    onChanged: (table) {
                      if (table != null) {
                        _loadTableData(table);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Seção SQL
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                const Text('Editor SQL:'),
                TextField(
                  controller: _sqlController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Digite seu comando SQL aqui...',
                  ),
                ),
                ElevatedButton(
                  onPressed: _executeSql,
                  child: const Text('Executar SQL'),
                ),
              ],
            ),
          ),
          
          // Resultados
          if (_sqlResult.isNotEmpty)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(8),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                          minHeight: constraints.maxHeight,
                        ),
                        child: SelectableText(
                          _sqlResult,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          
          // Dados da tabela
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedTable == null
                    ? const Center(child: Text('Selecione uma tabela'))
                    : _tableData.isEmpty
                        ? const Center(child: Text('Nenhum dado encontrado'))
                        : Column(
                            children: [
                              // Cabeçalho
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                color: Theme.of(context).primaryColor.withOpacity(0.1),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: _columns.map((column) {
                                      return SizedBox(
                                        width: 180,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Text(
                                            column,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).primaryColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              // Dados
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Column(
                                      children: _tableData.map((row) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.grey.shade300,
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: _columns.map((column) {
                                              return SizedBox(
                                                width: 180,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(8),
                                                  child: Text(
                                                    row[column]?.toString() ?? 'NULL',
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}