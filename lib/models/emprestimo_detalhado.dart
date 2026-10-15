import 'transacao.dart';
import 'transacao_pai.dart';

class EmprestimoDetalhado {
  final TransacaoPai emprestimo;
  final List<Transacao> parcelas;
  const EmprestimoDetalhado(this.emprestimo, this.parcelas);
  bool get pago =>
      parcelas.isNotEmpty &&
      parcelas.every((p) => p.dataPagamentoCompleto != null);
  double get jurosPagos => parcelas
      .where((p) => p.dataPagamentoRetorno != null)
      .fold(0, (s, p) => s + p.retorno);
}
