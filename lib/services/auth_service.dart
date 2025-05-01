import 'dart:convert';
import '../db.dart';
import '../utils/hash_helper.dart';
import 'package:crypto/crypto.dart';

class AuthService {
  Future<String?> autenticar(String telefone, String senha) async {
    final conn = await Database.connect();
    final result = await conn.query(
      'SELECT id, senha_hash FROM usuarios WHERE telefone = @tel',
      substitutionValues: {'tel': telefone},
    );

    if (result.isEmpty) return null;

    final storedHash = result.first[1] as String;
    final userId = result.first[0] as int;

    final senhaValida = verificarSenha(senha, storedHash);
    if (!senhaValida) return null;

    return userId.toString();
  }

  Future<void> registrar(String nome, String telefone, String senha) async {
    final conn = await Database.connect();
    final hash = gerarHashSenha(senha);

    await conn.query(
      'INSERT INTO usuarios (nome, telefone, senha_hash) VALUES (@n, @t, @s)',
      substitutionValues: {
        'n': nome,
        't': telefone,
        's': hash,
      },
    );
  }
}
