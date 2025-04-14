class Transacao {
  final int? id;
  final int idObrigado;
  final DateTime dataEmprestimo;
  final double valorEmprestado;
  final double percentualJuros;
  final double retorno;
  final DateTime? dataPagamentoRetorno;
  final DateTime? dataPagamentoCompleto;

  Transacao({
    this.id,
    required this.idObrigado,
    required this.dataEmprestimo,
    required this.valorEmprestado,
    required this.percentualJuros,
    required this.retorno,
    this.dataPagamentoRetorno,
    this.dataPagamentoCompleto,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_obrigado': idObrigado,
      'data_emprestimo': dataEmprestimo.toIso8601String(),
      'valor_emprestado': valorEmprestado,
      'percentual_juros': percentualJuros,
      'retorno': retorno,
      'data_pagamento_retorno': dataPagamentoRetorno?.toIso8601String(),
      'data_pagamento_completo': dataPagamentoCompleto?.toIso8601String(),
    };
  }

  factory Transacao.fromMap(Map<String, dynamic> map) {
    return Transacao(
      id: map['id'],
      idObrigado: map['id_obrigado'],
      dataEmprestimo: DateTime.parse(map['data_emprestimo']),
      valorEmprestado: map['valor_emprestado'],
      percentualJuros: map['percentual_juros'],
      retorno: map['retorno'],
      dataPagamentoRetorno: map['data_pagamento_retorno'] != null 
          ? DateTime.parse(map['data_pagamento_retorno']) 
          : null,
      dataPagamentoCompleto: map['data_pagamento_completo'] != null 
          ? DateTime.parse(map['data_pagamento_completo']) 
          : null,
    );
  }
}