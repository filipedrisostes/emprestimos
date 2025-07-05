// database_explorer_screen.dart
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:emprestimos/database_helper.dart';

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
        _sqlResult = 'Resultado: ${result.length} linhas afetadas\n';
        if (result.isNotEmpty) {
          _sqlResult += 'Colunas: ${result.first.keys.join(', ')}\n';
          _sqlResult += 'Dados:\n${result.map((e) => e.toString()).join('\n')}';
        }
        _isLoading = false;
      });
      
      // Recarrega a tabela atual se a SQL pode ter afetado os dados
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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _deleteRow(int id) async {
    if (_selectedTable == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: const Text('Tem certeza que deseja excluir este registro?'),
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
    
    if (confirm != true) return;
    
    setState(() => _isLoading = true);
    try {
      final db = await dbHelper.database;
      await db.delete(
        _selectedTable!,
        where: 'id = ?',
        whereArgs: [id],
      );
      await _loadTableData(_selectedTable!);
      _showError('Registro excluído com sucesso!');
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erro ao excluir: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorador do Banco de Dados'),
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
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _sqlResult,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ],
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
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: _columns.map((column) {
                                return DataColumn(label: Text(column));
                              }).toList(),
                              rows: _tableData.map((row) {
                                return DataRow(
                                  cells: _columns.map((column) {
                                    return DataCell(
                                      Text(row[column]?.toString() ?? 'NULL'),
                                      onTap: () {
                                        // Implemente a edição aqui se desejar
                                      },
                                    );
                                  }).toList(),
                                );
                              }).toList(),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}