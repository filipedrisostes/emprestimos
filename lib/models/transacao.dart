class Transacao {
  final int id;
  final int idObrigado;
  final DateTime dataEmprestimo;
  final DateTime? dataVencimento; // ✅ Novo campo opcional para vencimento
  final double valorEmprestado;
  final double percentualJuros;
  final double retorno;
  final DateTime? dataPagamentoRetorno;
  final DateTime? dataPagamentoCompleto;

  Transacao({
    required this.id,
    required this.idObrigado,
    required this.dataEmprestimo,
    this.dataVencimento,
    required this.valorEmprestado,
    required this.percentualJuros,
    required this.retorno,
    this.dataPagamentoRetorno,
    this.dataPagamentoCompleto,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'idObrigado': idObrigado,
      'dataEmprestimo': dataEmprestimo.toIso8601String(),
      'dataVencimento': dataVencimento?.toIso8601String(), // ✅ Novo campo salvo
      'valorEmprestado': valorEmprestado,
      'percentualJuros': percentualJuros,
      'retorno': retorno,
      'dataPagamentoRetorno': dataPagamentoRetorno?.toIso8601String(),
      'dataPagamentoCompleto': dataPagamentoCompleto?.toIso8601String(),
    };
  }

  factory Transacao.fromMap(Map<String, dynamic> map) {
  return Transacao(
    id: map['id'],
    idObrigado: map['id_obrigado'] != null ? map['id_obrigado'] as int : 0,
    dataEmprestimo: DateTime.parse(map['data_emprestimo']),
    dataVencimento: map['dataVencimento'] != null
        ? DateTime.parse(map['dataVencimento'])
        : null,
    valorEmprestado: (map['valor_emprestado'] ?? 0).toDouble(),
    percentualJuros: (map['percentual_juros'] ?? 0).toDouble(),
    retorno: (map['retorno'] ?? 0).toDouble(),
    dataPagamentoRetorno: map['data_pagamento_retorno'] != null
        ? DateTime.parse(map['data_pagamento_retorno'])
        : null,
    dataPagamentoCompleto: map['data_pagamento_completo'] != null
        ? DateTime.parse(map['data_pagamento_completo'])
        : null,
  );
}


}
