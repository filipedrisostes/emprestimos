import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emprestimos/services/app_lock_service.dart';

class FakeAuth extends LocalAuthentication {
  bool success = true, available = true;
  bool throwsError = false;
  @override
  Future<bool> get canCheckBiometrics async => available;
  @override
  Future<List<BiometricType>> getAvailableBiometrics() async =>
      available ? [BiometricType.fingerprint] : [];
  @override
  Future<bool> authenticate(
      {required String localizedReason,
      Iterable<dynamic> authMessages = const [],
      AuthenticationOptions options = const AuthenticationOptions()}) async {
    if (throwsError) throw StateError('sensor');
    return success;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('activation requires authentication, persists and locks next launch',
      () async {
    final auth = FakeAuth();
    final lock = AppLockService(auth: auth);
    await lock.initialize();
    expect(lock.enabled, false);
    await lock.setEnabled(true);
    expect(lock.enabled, true);
    lock.lock();
    expect(lock.locked, true);
    auth.success = false;
    await lock.unlock();
    expect(lock.locked, true);
    await lock.setEnabled(false);
    expect(lock.enabled, true);
    auth.success = true;
    await lock.unlock();
    expect(lock.locked, false);
    final next = AppLockService(auth: auth);
    await next.initialize();
    expect(next.locked, true);
    await next.setEnabled(false);
    expect(next.enabled, false);
  });
  test('missing biometrics cannot enable; sensor error cannot unlock',
      () async {
    final auth = FakeAuth()..available = false;
    final lock = AppLockService(auth: auth);
    await expectLater(lock.setEnabled(true), throwsStateError);
    expect(lock.enabled, false);
    auth.available = true;
    await lock.setEnabled(true);
    lock.lock();
    auth.throwsError = true;
    await lock.unlock();
    expect(lock.locked, true);
    expect(lock.error, isNotNull);
  });
}
