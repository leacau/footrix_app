import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class RememberedCredentials {
  final String email;
  final String password;
  final bool remember;
  final bool biometricEnabled;

  const RememberedCredentials({
    required this.email,
    required this.password,
    required this.remember,
    required this.biometricEnabled,
  });
}

class BiometricAuthService {
  static const _storage = FlutterSecureStorage();
  static final _localAuth = LocalAuthentication();
  static const _emailKey = 'remembered_email';
  static const _passwordKey = 'remembered_password';
  static const _rememberKey = 'remember_login';
  static const _biometricKey = 'biometric_login';

  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.isDeviceSupported() &&
          await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  static Future<RememberedCredentials> load() async {
    final values = await _storage.readAll();
    return RememberedCredentials(
      email: values[_emailKey] ?? '',
      password: values[_passwordKey] ?? '',
      remember: values[_rememberKey] == 'true',
      biometricEnabled: values[_biometricKey] == 'true',
    );
  }

  static Future<void> save({
    required String email,
    required String password,
    required bool biometricEnabled,
  }) async {
    await Future.wait([
      _storage.write(key: _emailKey, value: email.trim()),
      _storage.write(key: _passwordKey, value: password),
      _storage.write(key: _rememberKey, value: 'true'),
      _storage.write(
        key: _biometricKey,
        value: biometricEnabled ? 'true' : 'false',
      ),
    ]);
  }

  static Future<void> clear() => _storage.deleteAll();

  static Future<bool> authenticate() async {
    return _localAuth.authenticate(
      localizedReason: 'Ingresá a Footrix con tu identidad biométrica',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }
}
