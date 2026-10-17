class Transacao {
  final double valorPagoParcial;
  final DateTime? renegociadoEm;
  final bool parcelamento;
  bool get emAberto =>
      renegociadoEm == null &&
      dataPagamentoCompleto == null &&
      dataPagamentoRetorno == null;
  bool get parcial =>
      renegociadoEm != null || (emAberto && valorPagoParcial > 0);
  double get saldo => emAberto
      ? ((retorno * 100).round() - (valorPagoParcial * 100).round())
              .clamp(0, 9007199254740991) /
          100
      : 0;
  String get situacao => parcial
      ? 'Parcial'
      : dataPagamentoCompleto != null
          ? 'Quitada'
          : dataPagamentoRetorno != null
              ? 'Juros pagos'
              : 'Em aberto';
  final int? id;
  final int? idTransacaoPai;
  final int parcela;
  final int idObrigado;
  final DateTime dataEmprestimo;
  final DateTime? dataVencimento; // ✅ Novo campo opcional para vencimento
  final double valorEmprestado;
  final double percentualJuros;
  final double retorno;
  final DateTime? dataPagamentoRetorno;
  final DateTime? dataPagamentoCompleto;

  Transacao({
    this.valorPagoParcial = 0,
    this.renegociadoEm,
    this.parcelamento = false,
    this.id,
    this.idTransacaoPai,
    this.parcela = 1,
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
      'id_transacao_pai': idTransacaoPai,
      'parcela': parcela,
      'valor_pago_parcial': valorPagoParcial,
      'renegociado_em': renegociadoEm?.toIso8601String(),
      'parcelamento': parcelamento ? 1 : 0,
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
      valorPagoParcial: (map['valor_pago_parcial'] as num?)?.toDouble() ?? 0,
      renegociadoEm: map['renegociado_em'] == null
          ? null
          : DateTime.parse(map['renegociado_em']),
      parcelamento: map['parcelamento'] == 1,
      id: map['id'],
      idTransacaoPai: map['id_transacao_pai'] as int?,
      parcela: (map['parcela'] as int?) ?? 1,
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
      'id_transacao_pai': idTransacaoPai,
      'parcela': parcela,
      'valor_pago_parcial': valorPagoParcial,
      'renegociado_em': renegociadoEm?.toIso8601String(),
      'parcelamento': parcelamento ? 1 : 0,
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
