// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Footrix';

  @override
  String get loginWelcome => 'Predict. Compete. Climb.';

  @override
  String get emailHint => 'Email';

  @override
  String get passwordHint => 'Password';

  @override
  String get loginButton => 'Sign In';

  @override
  String get googleLogin => 'Continue with Google';

  @override
  String get noAccount => 'Don\'t have an account?';

  @override
  String get signUp => 'Sign Up';

  @override
  String get errorRequired => 'This field is required';

  @override
  String get errorEmail => 'Enter a valid email';

  @override
  String get errorPassword => 'Min 6 characters';

  @override
  String errorAuth(String error) {
    return 'Error: $error';
  }

  @override
  String get signOut => 'Sign Out';
}
