class TransacaoPai {
  int? id;
  DateTime dataEmprestimo;
  int idObrigado;
  double valorEmprestado;
  double percentualJuros;
  int qtdeParcelas;

  TransacaoPai({
    this.id,
    required this.dataEmprestimo,
    required this.idObrigado,
    required this.valorEmprestado,
    required this.percentualJuros,
    required this.qtdeParcelas,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'data_emprestimo': dataEmprestimo.toIso8601String(),
      'id_obrigado': idObrigado,
      'valor_emprestado': valorEmprestado,
      'percentual_juros': percentualJuros,
      'qtde_parcelas': qtdeParcelas,
    };
  }

  factory TransacaoPai.fromMap(Map<String, dynamic> map) {
    return TransacaoPai(
      id: map['id'],
      dataEmprestimo: DateTime.parse(map['data_emprestimo']),
      idObrigado: map['id_obrigado'],
      valorEmprestado: map['valor_emprestado'],
      percentualJuros: map['percentual_juros'],
      qtdeParcelas: map['qtde_parcelas'],
    );
  }
}
