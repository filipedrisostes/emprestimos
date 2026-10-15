import 'package:flutter_test/flutter_test.dart';
import 'package:emprestimos/models/obrigado.dart';

void main() {
  test('mensagem personalizada preserva o campo do banco', () {
    final cliente = Obrigado.fromMap({
      'id': 1,
      'nome': 'Teste',
      'zap': '11999990000',
      'mensagem_personalizada': 'Olá #'
    });
    expect(cliente.mensagemPersonalizada, 'Olá #');
    expect(cliente.toMap()['mensagem_personalizada'], 'Olá #');
  });
}
