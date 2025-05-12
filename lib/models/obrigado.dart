class Obrigado {
  final int? id;
  final String nome;
  final String zap;
  final String? mensagemPersonalizada; // ✅ Novo campo opcional para mensagem personalizada

  Obrigado({
    this.id,
    required this.nome,
    required this.zap,
    this.mensagemPersonalizada,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'zap': zap,
      'mensagem_personalizada': mensagemPersonalizada, // ✅ Adicionado aqui também
    };
  }

  factory Obrigado.fromMap(Map<String, dynamic> map) {
    return Obrigado(
      id: map['id'],
      nome: map['nome'],
      zap: map['zap'],
      mensagemPersonalizada: map['mensagem_personalizada'], // ✅ Carregar o novo campo
    );
  }

  // Converter a instância para JSON (Map)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'zap': zap,
      'mensagem_personalizada': mensagemPersonalizada ?? '',
    };
  }
  
  // Criar uma instância a partir de JSON (Map)
  factory Obrigado.fromJson(Map<String, dynamic> json) {
    return Obrigado(
      id: json['id'],
      nome: json['nome'],
      zap: json['zap'],
      mensagemPersonalizada: json['mensagem_personalizada'], // ✅ Corrigido
    );
  }
}
