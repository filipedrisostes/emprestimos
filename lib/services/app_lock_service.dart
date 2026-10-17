import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockService extends ChangeNotifier {
  static final instance = AppLockService();
  final LocalAuthentication _auth;
  AppLockService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();
  bool enabled = false, locked = true, authenticating = false;
  String? error;
  Future<void> initialize() async {
    enabled = (await SharedPreferences.getInstance())
            .getBool('device_biometric_lock') ??
        false;
    locked = enabled;
  }

  void lock() {
    if (enabled && !authenticating) {
      locked = true;
      notifyListeners();
    }
  }

  Future<bool> authenticate() async {
    if (authenticating) return false;
    authenticating = true;
    error = null;
    notifyListeners();
    try {
      final ok = await _auth.authenticate(
          localizedReason: 'Confirme sua identidade para acessar Empréstimos',
          options: const AuthenticationOptions(
              biometricOnly: false, stickyAuth: true));
      if (!ok) error = 'Autenticação cancelada. Tente novamente.';
      return ok;
    } catch (_) {
      error =
          'Não foi possível autenticar. Confira a biometria ou o código de bloqueio nos ajustes do aparelho.';
      return false;
    } finally {
      authenticating = false;
      notifyListeners();
    }
  }

  Future<void> unlock() async {
    if (await authenticate()) {
      locked = false;
      notifyListeners();
    }
  }

  Future<void> setEnabled(bool value) async {
    if (value &&
        (!(await _auth.canCheckBiometrics) ||
            (await _auth.getAvailableBiometrics()).isEmpty)) {
      throw StateError(
          'Cadastre uma biometria nos ajustes do aparelho antes de ativar.');
    }
    if (!await authenticate()) return;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool('device_biometric_lock', value))
      throw StateError('Não foi possível salvar a proteção.');
    enabled = value;
    locked = false;
    notifyListeners();
  }
}
