// test/dao/transacao_dao_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:emprestimos/dao/transacao_dao.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/models/transacao.dart';

void main() {
  late TransacaoDao dao;

  setUpAll(() async {
    dao = TransacaoDao(DatabaseHelper.instance);
    final db = await DatabaseHelper.instance.database;
    await db.execute('DELETE FROM transacoes');
  });

  test('inserir e recuperar transacao', () async {
    final t = Transacao(
      id: 0, // valor fictício, será ignorado se o banco usa AUTOINCREMENT
      idObrigado: 1,
      dataEmprestimo: DateTime.now(),
      valorEmprestado: 100.0,
      percentualJuros: 10.0,
      retorno: 10.0,
    );

    final id = await dao.insertTransacao(t);
    final list = await dao.getTransacoesByPeriodo(
      DateTime.now().subtract(Duration(days: 1)),
      DateTime.now().add(Duration(days: 1)),
    );

    expect(list.any((tx) => tx.id == id), isTrue);
  });
}
