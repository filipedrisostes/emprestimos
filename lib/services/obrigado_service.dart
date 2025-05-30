import '../dao/obrigado_dao.dart';
import '../database_helper.dart';
import '../models/obrigado.dart';

class ObrigadoService {
  final _dbHelper = DatabaseHelper.instance;
  late final ObrigadoDao _obrigadoDao = ObrigadoDao(_dbHelper);

  Future<int> saveManualContact(Obrigado obrigado) async {
    return await _obrigadoDao.insertObrigado(obrigado);
  }

  Future<List<Obrigado>> getAllObrigados() async {
    return await _obrigadoDao.getAllObrigados();
  }
}
