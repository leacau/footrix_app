// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Footrix';

  @override
  String get loginWelcome => 'Predice. Compite. Escala.';

  @override
  String get emailHint => 'Correo electrónico';

  @override
  String get passwordHint => 'Contraseña';

  @override
  String get loginButton => 'Iniciar sesión';

  @override
  String get googleLogin => 'Continuar con Google';

  @override
  String get noAccount => '¿No tienes cuenta?';

  @override
  String get signUp => 'Registrarse';

  @override
  String get errorRequired => 'Este campo es obligatorio';

  @override
  String get errorEmail => 'Ingresa un correo válido';

  @override
  String get errorPassword => 'Mínimo 6 caracteres';

  @override
  String errorAuth(String error) {
    return 'Error: $error';
  }

  @override
  String get signOut => 'Cerrar sesión';
}
