class Obrigado {
  final int? id;
  final String nome;
  final String zap;

  Obrigado({
    this.id,
    required this.nome,
    required this.zap,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'zap': zap,
    };
  }

  factory Obrigado.fromMap(Map<String, dynamic> map) {
    return Obrigado(
      id: map['id'],
      nome: map['nome'],
      zap: map['zap'],
    );
  }
}