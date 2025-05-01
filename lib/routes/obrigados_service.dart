import 'dart:convert';
import '../db.dart';

class ObrigadosService {
  Future<String> getTodosObrigados() async {
    final conn = await Database.connect();
    final results = await conn.query('SELECT * FROM obrigados');
    final data = results
        .map((row) => {
              'id': row[0],
              'nome': row[1],
              'zap': row[2],
              'mensagem_personalizada': row[3]
            })
        .toList();

    return jsonEncode(data);
  }

  Future<String> criarObrigado(String body) async {
    final conn = await Database.connect();
    final data = jsonDecode(body);

    await conn.query(
      'INSERT INTO obrigados (nome, zap, mensagem_personalizada) VALUES (@nome, @zap, @msg)',
      substitutionValues: {
        'nome': data['nome'],
        'zap': data['zap'],
        'msg': data['mensagem_personalizada'] ?? ''
      },
    );

    return jsonEncode({'status': 'ok'});
  }
}
