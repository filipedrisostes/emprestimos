import 'package:flutter/material.dart';
import '../database_helper.dart';

class DatabaseExplorerScreen extends StatefulWidget {
  const DatabaseExplorerScreen({super.key});
  @override
  State<DatabaseExplorerScreen> createState() => _DatabaseExplorerScreenState();
}

class _DatabaseExplorerScreenState extends State<DatabaseExplorerScreen> {
  String _table = 'obrigados';
  late Future<List<Map<String, Object?>>> _rows = _load();
  Future<List<Map<String, Object?>>> _load() async =>
      (await DatabaseHelper.instance.database).query(_table);
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar:
          AppBar(title: const Text('Explorador de Banco de Dados'), actions: [
        IconButton(
            onPressed: () => setState(() => _rows = _load()),
            icon: const Icon(Icons.refresh)),
      ]),
      body: Column(children: [
        DropdownButton<String>(
            value: _table,
            items: [
              for (final t in ['obrigados', 'transacao_pai', 'transacoes'])
                DropdownMenuItem(value: t, child: Text(t))
            ],
            onChanged: (t) {
              if (t != null)
                setState(() {
                  _table = t;
                  _rows = _load();
                });
            }),
        Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
                future: _rows,
                builder: (_, s) {
                  if (s.hasError) return Center(child: Text('${s.error}'));
                  if (!s.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final rows = s.data!;
                  if (rows.isEmpty)
                    return const Center(
                        child: Text('Nenhum registro encontrado'));
                  return SingleChildScrollView(
                      child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: [
                              for (final k in rows.first.keys)
                                DataColumn(label: Text(k))
                            ],
                            rows: [
                              for (final row in rows)
                                DataRow(cells: [
                                  for (final v in row.values)
                                    DataCell(SelectableText('${v ?? ''}'))
                                ])
                            ],
                          )));
                })),
      ]));
}
