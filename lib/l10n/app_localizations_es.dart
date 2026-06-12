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
  String get signOut => 'Cerrar sesión';

  @override
  String get name => 'Nombre';

  @override
  String get alreadyHaveAccount => '¿Ya tienes cuenta? Iniciar sesión';

  @override
  String get incorrectCredentials => 'Correo o contraseña incorrectos';

  @override
  String get emailAlreadyInUse => 'Este correo ya está registrado';

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
  String get error => 'Error';

  @override
  String get home => 'Inicio';

  @override
  String get fixture => 'Fixture';

  @override
  String get groups => 'Grupos';

  @override
  String get rankings => 'Rankings';

  @override
  String get profile => 'Perfil';

  @override
  String get admin => 'Admin';

  @override
  String get settings => 'Ajustes';

  @override
  String get language => 'Idioma';

  @override
  String get spanish => 'Español';

  @override
  String get english => 'English';

  @override
  String languageChanged(String language) {
    return 'Idioma: $language';
  }

  @override
  String get notifications => 'Notificaciones';

  @override
  String get enablePush => 'Activar push';

  @override
  String get close => 'Cerrar';

  @override
  String get save => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get create => 'Crear';

  @override
  String get join => 'Unirse';

  @override
  String get all => 'Todas';

  @override
  String get allLeagues => 'Todas las ligas';

  @override
  String get noName => 'Sin nombre';

  @override
  String get unnamed => 'Sin nombre';

  @override
  String get anonymous => 'Anónimo';

  @override
  String get unspecified => 'No especificado';

  @override
  String helloUser(String name) {
    return '¡Hola, $name!';
  }

  @override
  String get user => 'Usuario';

  @override
  String get chooseSection => 'Elegí una sección para comenzar:';

  @override
  String get fixtureSubtitle => 'Predice partidos';

  @override
  String get groupsSubtitle => 'Competí con amigos';

  @override
  String get rankingsSubtitle => 'Tabla de posiciones';

  @override
  String get profileSubtitle => 'Mis datos y stats';

  @override
  String get settingsSubtitle => 'Idioma, notificaciones';

  @override
  String get adminSubtitle => 'Gestión';

  @override
  String get myProfile => 'Mi Perfil';

  @override
  String get myStats => 'Tus Stats';

  @override
  String get points => 'Puntos';

  @override
  String get leaguesToPlay => 'Ligas para jugar';

  @override
  String get leaguesSaved => 'Ligas guardadas';

  @override
  String get noLeagueSelection => 'Sin selección: se muestran todas las ligas del día.';

  @override
  String selectedLeagueCount(int count) {
    return '$count ligas seleccionadas';
  }

  @override
  String get errorLoadingLeagues => 'Error cargando ligas';

  @override
  String get predictions => 'Predicciones';

  @override
  String get totalPoints => 'Puntos totales';

  @override
  String get location => 'Ubicación';

  @override
  String get country => 'País';

  @override
  String get provinceState => 'Provincia/Estado';

  @override
  String get city => 'Ciudad';

  @override
  String get myGroups => 'Mis Grupos';

  @override
  String get createGroup => 'Crear Grupo';

  @override
  String get groupName => 'Nombre del Grupo';

  @override
  String get groupNameHint => 'Ej: Oficina, Familia, Amigos';

  @override
  String get leagueCompetition => 'Liga/Competencia:';

  @override
  String get onlyThisLeague => 'Solo esta liga';

  @override
  String get leagueExclusiveSubtitle => 'El ranking solo contará partidos de la liga seleccionada';

  @override
  String get groupCreated => 'Grupo creado';

  @override
  String get selectLeagueWarning => 'Seleccioná una liga para continuar';

  @override
  String get joinGroup => 'Unirse a Grupo';

  @override
  String get sixCharacterCode => 'Código de 6 caracteres';

  @override
  String get codeExample => 'Ej: X7K9P2';

  @override
  String get joinedGroup => 'Te uniste al grupo';

  @override
  String get noGroupsYet => 'No perteneces a ningún grupo aún.';

  @override
  String get code => 'Código';

  @override
  String get league => 'Liga';

  @override
  String get allLeaguesName => 'Todas las ligas';

  @override
  String get exclusive => 'exclusiva';

  @override
  String get inviteWhatsapp => 'Invitar por WhatsApp';

  @override
  String codeCopied(String code) {
    return 'Código copiado: $code';
  }

  @override
  String whatsappInvite(String groupName, String code) {
    return 'Te invito a jugar en mi grupo \"$groupName\" de Footrix.\nCódigo del grupo: $code\nAbrí Footrix > Grupos > Unirse a grupo y pegá el código.';
  }

  @override
  String get rankingsTitle => 'Rankings';

  @override
  String get clearFilters => 'Limpiar filtros';

  @override
  String get worldwide => 'Mundial';

  @override
  String get province => 'Provincia';

  @override
  String get filterHint => 'Filtrar...';

  @override
  String get noDataForLeague => 'Sin datos para esta liga';

  @override
  String get noUsersForFilter => 'Sin usuarios para este filtro';

  @override
  String get noLocation => 'Sin ubicación';

  @override
  String pointsSuffix(int points) {
    return '$points pts';
  }

  @override
  String get adminPanel => 'Panel Admin';

  @override
  String get noAdminPermission => 'No tenés permisos de administrador';

  @override
  String get syncFifa => 'Sincronizar FIFA';

  @override
  String get users => 'Usuarios';

  @override
  String get createMatch => 'Crear Partido';

  @override
  String get finish => 'Finalizar';

  @override
  String fifaSynced(int matches, int leagues) {
    return 'FIFA sincronizado: $matches partidos, $leagues ligas';
  }

  @override
  String get syncFifaError => 'Error sincronizando FIFA';

  @override
  String get predictionSettings => 'Predicciones';

  @override
  String get predictionLockLabel => 'Cerrar predicciones X horas antes';

  @override
  String get predictionLockHelper => 'Usa 0 para aceptar hasta la hora de inicio.';

  @override
  String get saveSettings => 'Guardar ajustes';

  @override
  String get checkNumericValues => 'Revisá los valores numéricos';

  @override
  String get settingsSaved => 'Ajustes guardados';

  @override
  String get homeTeam => 'Equipo Local';

  @override
  String get awayTeam => 'Equipo Visitante';

  @override
  String get phaseExample => 'Fase (Ej: Grupo A)';

  @override
  String get dateTimeFormat => 'Fecha y Hora (YYYY-MM-DD HH:MM)';

  @override
  String get lockPredictionsBefore => 'Bloquear predicciones X horas antes';

  @override
  String hoursBefore(int hours) {
    return '$hours horas antes';
  }

  @override
  String get matchCreated => 'Partido creado';

  @override
  String get dateFormatError => 'Error: Formato de fecha incorrecto';

  @override
  String get finishMatch => 'Finalizar Partido';

  @override
  String get homeGoals => 'Goles Local';

  @override
  String get awayGoals => 'Goles Visita';

  @override
  String get noPendingMatches => 'No hay partidos pendientes';

  @override
  String get noSchedule => 'Sin horario';

  @override
  String get moreOptions => 'Más opciones';

  @override
  String get past => 'Pasados';

  @override
  String get today => 'Hoy';

  @override
  String get tomorrow => 'Mañana';

  @override
  String get more => 'Más';

  @override
  String get noPastMatches => 'No hay partidos pasados para tus ligas.';

  @override
  String get noMatchesToday => 'No hay partidos para hoy.';

  @override
  String get noMatchesTomorrow => 'No hay partidos para mañana.';

  @override
  String get noMatchesDate => 'No hay partidos para esta fecha.';

  @override
  String get noMoreMatches => 'No hay más partidos cargados.';

  @override
  String get unableLoadFixture => 'No se pudo cargar el fixture.';

  @override
  String get live => 'En vivo';

  @override
  String get otherTournaments => 'Otros torneos';

  @override
  String get detail => 'Detalle';

  @override
  String get matchLocked => 'Partido bloqueado';

  @override
  String get homeShort => 'Local';

  @override
  String get awayShort => 'Visita';

  @override
  String get sendPrediction => 'Enviar Predicción';

  @override
  String get finished => 'FINALIZADO';

  @override
  String get yourPrediction => 'Tu predicción:';

  @override
  String get closedBefore => 'Cerrado 12hs antes';

  @override
  String get notAuthenticated => 'No autenticado';

  @override
  String get saved => 'Guardada';

  @override
  String get dateTba => 'Fecha TBA';

  @override
  String get inPlay => 'En juego';

  @override
  String todayAt(String time) {
    return 'Hoy $time';
  }

  @override
  String get dateToBeConfirmed => 'Fecha a confirmar';

  @override
  String localDeviceTime(String date, String zone) {
    return '$date - hora local del dispositivo ($zone)';
  }
}
