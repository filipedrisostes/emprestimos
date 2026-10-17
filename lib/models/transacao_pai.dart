class TransacaoPai {
  final int? origemEmprestimoId;
  final String? origemHistorico;
  bool get parcelamento => origemEmprestimoId != null;
  final int? id;
  final int idObrigado;
  final DateTime dataEmprestimo;
  final double valorEmprestado;
  final double percentualJuros;
  final int qtdeParcelas;

  const TransacaoPai(
      {this.origemEmprestimoId,
      this.origemHistorico,
      this.id,
      required this.idObrigado,
      required this.dataEmprestimo,
      required this.valorEmprestado,
      required this.percentualJuros,
      required this.qtdeParcelas});

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'origem_emprestimo_id': origemEmprestimoId,
        'origem_historico': origemHistorico,
        'id_obrigado': idObrigado,
        'data_emprestimo': dataEmprestimo.toIso8601String(),
        'valor_emprestado': valorEmprestado,
        'percentual_juros': percentualJuros,
        'qtde_parcelas': qtdeParcelas,
      };

  factory TransacaoPai.fromMap(Map<String, Object?> map) => TransacaoPai(
        origemEmprestimoId: map['origem_emprestimo_id'] as int?,
        origemHistorico: map['origem_historico'] as String?,
        id: map['id'] as int?,
        idObrigado: map['id_obrigado'] as int,
        dataEmprestimo: DateTime.parse(map['data_emprestimo'] as String),
        valorEmprestado: (map['valor_emprestado'] as num).toDouble(),
        percentualJuros: (map['percentual_juros'] as num).toDouble(),
        qtdeParcelas: map['qtde_parcelas'] as int,
      );
}
