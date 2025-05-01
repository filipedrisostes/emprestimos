import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/obrigados_service.dart';

class ObrigadosRoutes {
  final _service = ObrigadosService();

  Router get router {
    final router = Router();

    router.get('/', _getTodos);
    router.post('/', _criar);

    return router;
  }

  Future<Response> _getTodos(Request request) async {
    final data = await _service.getTodosObrigados();
    return Response.ok(data, headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _criar(Request request) async {
    final body = await request.readAsString();
    final result = await _service.criarObrigado(body);
    return Response.ok(result, headers: {'Content-Type': 'application/json'});
  }
}
