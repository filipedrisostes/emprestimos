import 'database_helper.dart';

class ConfiguracaoRepository {
  final DatabaseHelper helper;
  ConfiguracaoRepository(this.helper);

  Future<Map<String, Object?>> carregar() async =>
      (await (await helper.database).query('configuracoes', where: 'id = 1'))
          .single;

  Future<void> salvar(Map<String, Object?> valores) =>
      helper.write((txn) async {
        final current =
            (await txn.query('configuracoes', where: 'id = 1')).single;
        if (valores.entries.every((e) => current[e.key] == e.value)) return;
        await txn.update('configuracoes', valores, where: 'id = 1');
      });
}

class ConfiguracaoService {
  static ConfiguracaoRepository get _repository =>
      ConfiguracaoRepository(DatabaseHelper.instance);

  static Future<double> getJurosPadrao() async =>
      ((await _repository.carregar())['juros_padrao'] as num).toDouble();
  static Future<int> getDiasVencimentoPadrao() async =>
      (await _repository.carregar())['dias_vencimento_padrao'] as int;
  static Future<String> getEmailPadrao() async =>
      (await _repository.carregar())['email_padrao'] as String;
  static Future<String> getZapPadrao() async =>
      (await _repository.carregar())['zap_padrao'] as String;

  static Future<void> salvar(
          {required double juros,
          required String email,
          required String celular,
          required int diasVencimento}) =>
      _repository.salvar({
        'juros_padrao': juros,
        'email_padrao': email,
        'zap_padrao': celular,
        'dias_vencimento_padrao': diasVencimento
      });

  static Future<void> setJurosPadrao(double valor) =>
      _repository.salvar({'juros_padrao': valor});
  static Future<void> setEmailPadrao(String valor) =>
      _repository.salvar({'email_padrao': valor});
  static Future<void> setZapPadrao(String valor) =>
      _repository.salvar({'zap_padrao': valor});
  static Future<void> setDiasVencimentoPadrao(int valor) =>
      _repository.salvar({'dias_vencimento_padrao': valor});
}
