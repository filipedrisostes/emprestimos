import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

const _secret = 'sua_chave_secreta_123456'; // Ideal usar .env

String gerarJwt(String userId) {
  final jwt = JWT({'id': userId});
  return jwt.sign(SecretKey(_secret), expiresIn: const Duration(days: 7));
}

bool verificarJwt(String token) {
  try {
    JWT.verify(token, SecretKey(_secret));
    return true;
  } catch (_) {
    return false;
  }
}
