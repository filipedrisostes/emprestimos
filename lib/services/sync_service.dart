import 'dart:convert';
import '../db.dart';

class SyncService {
  Future<String> processarSync(String body) async {
    final conn = await Database.connect();
    final data = jsonDecode(body);

    final obrigados = data['obrigados'] as List<dynamic>;
    final transacoes = data['transacoes'] as List<dynamic>;

    // Sincroniza obrigados
    for (var o in obrigados) {
      await conn.query('''
        INSERT INTO obrigados (id, nome, zap, mensagem_personalizada)
        VALUES (@id, @nome, @zap, @msg)
        ON CONFLICT (id) DO UPDATE SET
          nome = EXCLUDED.nome,
          zap = EXCLUDED.zap,
          mensagem_personalizada = EXCLUDED.mensagem_personalizada
      ''', substitutionValues: {
        'id': o['id'],
        'nome': o['nome'],
        'zap': o['zap'],
        'msg': o['mensagem_personalizada'] ?? '',
      });
    }

    // Sincroniza transações
    for (var t in transacoes) {
      await conn.query('''
        INSERT INTO transacoes (
          id, id_obrigado, data_emprestimo, valor_emprestado, percentual_juros,
          retorno, data_pagamento_retorno, data_pagamento_completo, data_vencimento
        )
        VALUES (
          @id, @id_obrigado, @data_emprestimo, @valor_emprestado, @percentual_juros,
          @retorno, @data_pagamento_retorno, @data_pagamento_completo, @data_vencimento
        )
        ON CONFLICT (id) DO UPDATE SET
          valor_emprestado = EXCLUDED.valor_emprestado,
          percentual_juros = EXCLUDED.percentual_juros,
          retorno = EXCLUDED.retorno,
          data_pagamento_retorno = EXCLUDED.data_pagamento_retorno,
          data_pagamento_completo = EXCLUDED.data_pagamento_completo,
          data_vencimento = EXCLUDED.data_vencimento
      ''', substitutionValues: {
        'id': t['id'],
        'id_obrigado': t['id_obrigado'],
        'data_emprestimo': DateTime.parse(t['data_emprestimo']),
        'valor_emprestado': t['valor_emprestado'],
        'percentual_juros': t['percentual_juros'],
        'retorno': t['retorno'],
        'data_pagamento_retorno': t['data_pagamento_retorno'] != null
            ? DateTime.parse(t['data_pagamento_retorno'])
            : null,
        'data_pagamento_completo': t['data_pagamento_completo'] != null
            ? DateTime.parse(t['data_pagamento_completo'])
            : null,
        'data_vencimento': DateTime.parse(t['data_vencimento']),
      });
    }

    return jsonEncode({'status': 'ok'});
  }
}
