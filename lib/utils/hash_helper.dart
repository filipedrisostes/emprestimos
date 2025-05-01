import 'package:crypto/crypto.dart';
import 'dart:convert';

String gerarHashSenha(String senha) {
  final bytes = utf8.encode(senha);
  return sha256.convert(bytes).toString(); // Use Argon2id para produção
}

bool verificarSenha(String senha, String hashSalvo) {
  final novoHash = gerarHashSenha(senha);
  return novoHash == hashSalvo;
}
