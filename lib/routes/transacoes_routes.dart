import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/transacoes_service.dart';

class TransacoesRoutes {
  final _service = TransacoesService();

  Router get router {
    final router = Router();

    router.get('/', _getTodas);
    router.post('/', _criar);

    return router;
  }

  Future<Response> _getTodas(Request request) async {
    final data = await _service.getTodasTransacoes();
    return Response.ok(data, headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _criar(Request request) async {
    final body = await request.readAsString();
    final result = await _service.criarTransacao(body);
    return Response.ok(result, headers: {'Content-Type': 'application/json'});
  }
}
