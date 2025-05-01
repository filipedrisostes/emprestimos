import 'package:shelf/shelf.dart';
import '../utils/jwt_helper.dart';

Middleware jwtMiddleware() {
  return (innerHandler) {
    return (request) async {
      final auth = request.headers['Authorization'];

      if (auth == null || !auth.startsWith('Bearer ')) {
        return Response.forbidden('Token não informado');
      }

      final token = auth.substring(7);
      final isValid = verificarJwt(token);

      if (!isValid) return Response.forbidden('Token inválido');

      return innerHandler(request);
    };
  };
}
