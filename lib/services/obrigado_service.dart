import '../dao/transacao_pai_dao.dart';
import '../dao/transacao_dao.dart';
import '../database_helper.dart';
import '../models/emprestimo_detalhado.dart';

class ObrigadoService {
  final DatabaseHelper db;
  ObrigadoService(this.db);
  Future<List<EmprestimoDetalhado>> detalhes(int id) async {
    final pais = await TransacaoPaiDao(db).getByObrigado(id);
    final parcelas = await TransacaoDao(db).getTransacoesByObrigado(id);
    return pais
        .map((p) => EmprestimoDetalhado(
            p, parcelas.where((t) => t.idTransacaoPai == p.id).toList()))
        .toList();
  }
}
