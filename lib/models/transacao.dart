class Transacao {
  int? id;
  double retorno;
  int idTransacaoPai;
  int parcela;
  final DateTime? dataVencimento;
  final DateTime? dataPagamentoRetorno;
  final DateTime? dataPagamentoCompleto;

  Transacao({
    this.id,
    required this.retorno,
    required this.idTransacaoPai,
    required this.parcela,
    this.dataPagamentoRetorno,
    this.dataPagamentoCompleto,
    this.dataVencimento,
  });

  Map<String, dynamic> toMap() {
    final map = {
      'id': id,
      'retorno': retorno,
      'id_transacao_pai': idTransacaoPai,
      'parcela': parcela,
      'data_pagamento_retorno': dataPagamentoRetorno?.toIso8601String(),
      'data_pagamento_completo': dataPagamentoCompleto?.toIso8601String(),
      'data_vencimento': dataVencimento?.toIso8601String()
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  factory Transacao.fromMap(Map<String, dynamic> map) {
    return Transacao(
      id: map['id'],
      retorno: map['retorno'],
      idTransacaoPai: map['id_transacao_pai'],
      parcela: map['parcela'],
      dataPagamentoRetorno: map['data_pagamento_retorno'] != null
          ? DateTime.parse(map['data_pagamento_retorno'])
          : null,
      dataPagamentoCompleto: map['data_pagamento_completo'] != null
          ? DateTime.parse(map['data_pagamento_completo'])
          : null,
      dataVencimento: map['data_vencimento'] != null
          ? DateTime.parse(map['data_vencimento'])
          : null,
    );
  }
}
