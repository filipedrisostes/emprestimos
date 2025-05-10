class Transacao {
  final int? id;
  final int idObrigado;
  final DateTime dataEmprestimo;
  final DateTime? dataVencimento; // ✅ Novo campo opcional para vencimento
  final double valorEmprestado;
  final double percentualJuros;
  final double retorno;
  final DateTime? dataPagamentoRetorno;
  final DateTime? dataPagamentoCompleto;

  Transacao({
    this.id,
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
    final map = {
      'id_obrigado': idObrigado,
      'data_emprestimo': dataEmprestimo.toIso8601String(),
      'valor_empresado': valorEmprestado,
      'percentual_juros': percentualJuros,
      'retorno': retorno,
      'data_pagamento_retorno': dataPagamentoRetorno?.toIso8601String(),
      'data_pagamento_completo': dataPagamentoCompleto?.toIso8601String(),
      'data_vencimento': dataVencimento?.toIso8601String(),
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }



  factory Transacao.fromMap(Map<String, dynamic> map) {
    return Transacao(
      id: map['id'],
      idObrigado: map['id_obrigado'] != null ? map['id_obrigado'] as int : 0,
      dataEmprestimo: DateTime.parse(map['data_emprestimo']),
      dataVencimento: map['data_vencimento'] != null
          ? DateTime.parse(map['data_vencimento'])
          : null,
      valorEmprestado: (map['valor_empresado'] ?? 0).toDouble(),
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

  // Converter a instância para JSON (Map)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'id_obrigado': idObrigado,
      'data_emprestimo': dataEmprestimo.toIso8601String(),
      'valor_empresado': valorEmprestado,
      'percentual_juros': percentualJuros,
      'retorno': retorno,
      'data_pagamento_retorno': dataPagamentoRetorno?.toIso8601String(),
      'data_pagamento_completo': dataPagamentoCompleto?.toIso8601String(),
      'data_vencimento': dataVencimento?.toIso8601String(),
    };
  }
}
