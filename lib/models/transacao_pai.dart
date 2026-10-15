class TransacaoPai {
  final int? id;
  final int idObrigado;
  final DateTime dataEmprestimo;
  final double valorEmprestado;
  final double percentualJuros;
  final int qtdeParcelas;

  const TransacaoPai(
      {this.id,
      required this.idObrigado,
      required this.dataEmprestimo,
      required this.valorEmprestado,
      required this.percentualJuros,
      required this.qtdeParcelas});

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'id_obrigado': idObrigado,
        'data_emprestimo': dataEmprestimo.toIso8601String(),
        'valor_emprestado': valorEmprestado,
        'percentual_juros': percentualJuros,
        'qtde_parcelas': qtdeParcelas,
      };

  factory TransacaoPai.fromMap(Map<String, Object?> map) => TransacaoPai(
        id: map['id'] as int?,
        idObrigado: map['id_obrigado'] as int,
        dataEmprestimo: DateTime.parse(map['data_emprestimo'] as String),
        valorEmprestado: (map['valor_emprestado'] as num).toDouble(),
        percentualJuros: (map['percentual_juros'] as num).toDouble(),
        qtdeParcelas: map['qtde_parcelas'] as int,
      );
}
