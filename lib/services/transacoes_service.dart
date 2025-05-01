import 'dart:convert';
import '../db.dart';

class TransacoesService {
  Future<String> getTodasTransacoes() async {
    final conn = await Database.connect();
    final results = await conn.query('SELECT * FROM transacoes ORDER BY id DESC');
    final data = results
        .map((row) => {
              'id': row[0],
              'id_obrigado': row[1],
              'data_emprestimo': row[2]?.toIso8601String(),
              'valor_emprestado': row[3],
              'percentual_juros': row[4],
              'retorno': row[5],
              'data_pagamento_retorno': row[6]?.toIso8601String(),
              'data_pagamento_completo': row[7]?.toIso8601String(),
              'data_vencimento': row[8]?.toIso8601String(),
            })
        .toList();

    return jsonEncode(data);
  }

  Future<String> criarTransacao(String body) async {
    final conn = await Database.connect();
    final data = jsonDecode(body);

    await conn.query('''
      INSERT INTO transacoes (
        id_obrigado, data_emprestimo, valor_emprestado, percentual_juros,
        retorno, data_pagamento_retorno, data_pagamento_completo, data_vencimento
      ) VALUES (
        @id_obrigado, @data_emprestimo, @valor_emprestado, @percentual_juros,
        @retorno, @data_pagamento_retorno, @data_pagamento_completo, @data_vencimento
      )
    ''', substitutionValues: {
      'id_obrigado': data['id_obrigado'],
      'data_emprestimo': DateTime.parse(data['data_emprestimo']),
      'valor_emprestado': data['valor_emprestado'],
      'percentual_juros': data['percentual_juros'],
      'retorno': data['retorno'],
      'data_pagamento_retorno': data['data_pagamento_retorno'] != null
          ? DateTime.parse(data['data_pagamento_retorno'])
          : null,
      'data_pagamento_completo': data['data_pagamento_completo'] != null
          ? DateTime.parse(data['data_pagamento_completo'])
          : null,
      'data_vencimento': DateTime.parse(data['data_vencimento']),
    });

    return jsonEncode({'status': 'ok'});
  }
}
