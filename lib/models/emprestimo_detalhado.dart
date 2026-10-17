import 'transacao.dart';
import 'transacao_pai.dart';

class EmprestimoDetalhado {
  final TransacaoPai emprestimo;
  final List<Transacao> parcelas;
  const EmprestimoDetalhado(this.emprestimo, this.parcelas);
  bool get pago =>
      parcelas.isNotEmpty &&
      parcelas.every((p) => p.dataPagamentoCompleto != null);
  bool get parcial => parcelas.any((p) => p.parcial);
  String get situacao => pago
      ? 'Pago'
      : parcial
          ? 'Parcial'
          : 'Em Aberto';
  double get jurosPagos => parcelas.where((p) => !p.parcelamento).fold(
      0,
      (s, p) =>
          s +
          (p.dataPagamentoRetorno != null ? p.retorno : p.valorPagoParcial));
}
