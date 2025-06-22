// lib/models/emprestimo_detalhado.dart
import 'package:emprestimos/models/transacao_pai.dart';
import 'package:emprestimos/models/transacao.dart';

class EmprestimoDetalhado {
  final TransacaoPai emprestimo;
  final List<Transacao> parcelas;
  final bool estaPago;
  bool isExpanded;

  EmprestimoDetalhado({
    required this.emprestimo,
    required this.parcelas,
    required this.estaPago,
    this.isExpanded = false,
  });
}