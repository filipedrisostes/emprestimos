import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class AuthRoutes {
  Router get router {
    final router = Router();

    router.post('/login', _loginHandler);
    router.post('/register', _registerHandler);

    return router;
  }

  Future<Response> _loginHandler(Request request) async {
    final body = await request.readAsString();
    // Aqui você faria parsing do JSON e validação no banco
    return Response.ok('Login recebido: $body');
  }

  Future<Response> _registerHandler(Request request) async {
    final body = await request.readAsString();
    // Aqui você criaria o usuário no banco
    return Response.ok('Registro recebido: $body');
  }
}
    