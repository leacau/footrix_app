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
  String get signOut => 'Sign Out';

  @override
  String get name => 'Name';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get incorrectCredentials => 'Incorrect email or password';

  @override
  String get emailAlreadyInUse => 'This email is already registered';

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
  String get error => 'Error';

  @override
  String get home => 'Home';

  @override
  String get fixture => 'Fixture';

  @override
  String get trivia => 'Trivia';

  @override
  String get groups => 'Groups';

  @override
  String get rankings => 'Rankings';

  @override
  String get profile => 'Profile';

  @override
  String get admin => 'Admin';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get spanish => 'Español';

  @override
  String get english => 'English';

  @override
  String languageChanged(String language) {
    return 'Language: $language';
  }

  @override
  String get notifications => 'Notifications';

  @override
  String get enablePush => 'Enable push';

  @override
  String get close => 'Close';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get create => 'Create';

  @override
  String get join => 'Join';

  @override
  String get play => 'Play';

  @override
  String get all => 'All';

  @override
  String get allLeagues => 'All leagues';

  @override
  String get noName => 'No name';

  @override
  String get unnamed => 'Unnamed';

  @override
  String get anonymous => 'Anonymous';

  @override
  String get unspecified => 'Not specified';

  @override
  String helloUser(String name) {
    return 'Hi, $name!';
  }

  @override
  String get user => 'User';

  @override
  String get chooseSection => 'Choose a section to start:';

  @override
  String get fixtureSubtitle => 'Predict matches';

  @override
  String get triviaSubtitle => 'Quick questions';

  @override
  String get groupsSubtitle => 'Compete with friends';

  @override
  String get rankingsSubtitle => 'Leaderboard';

  @override
  String get profileSubtitle => 'My data and stats';

  @override
  String get settingsSubtitle => 'Language, notifications';

  @override
  String get adminSubtitle => 'Management';

  @override
  String get myProfile => 'My Profile';

  @override
  String get myStats => 'Your Stats';

  @override
  String get points => 'Points';

  @override
  String get streak => 'Streak';

  @override
  String get leaguesToPlay => 'Leagues to play';

  @override
  String get leaguesSaved => 'Leagues saved';

  @override
  String get noLeagueSelection => 'No selection: all leagues for the day are shown.';

  @override
  String selectedLeagueCount(int count) {
    return '$count leagues selected';
  }

  @override
  String get errorLoadingLeagues => 'Error loading leagues';

  @override
  String get predictions => 'Predictions';

  @override
  String get totalPoints => 'Total points';

  @override
  String get triviaPoints => 'Trivia points';

  @override
  String get currentStreak => 'Current streak';

  @override
  String get bestStreak => 'Best streak';

  @override
  String get answeredQuestions => 'Answered questions';

  @override
  String get location => 'Location';

  @override
  String get country => 'Country';

  @override
  String get provinceState => 'State/Province';

  @override
  String get city => 'City';

  @override
  String get myGroups => 'My Groups';

  @override
  String get createGroup => 'Create Group';

  @override
  String get groupName => 'Group Name';

  @override
  String get groupNameHint => 'E.g. Office, Family, Friends';

  @override
  String get leagueCompetition => 'League/Competition:';

  @override
  String get onlyThisLeague => 'Only this league';

  @override
  String get leagueExclusiveSubtitle => 'The ranking will only count matches from the selected league';

  @override
  String get groupCreated => 'Group created';

  @override
  String get selectLeagueWarning => 'Select a league to continue';

  @override
  String get joinGroup => 'Join Group';

  @override
  String get sixCharacterCode => '6-character code';

  @override
  String get codeExample => 'E.g. X7K9P2';

  @override
  String get joinedGroup => 'You joined the group';

  @override
  String get noGroupsYet => 'You do not belong to any group yet.';

  @override
  String get code => 'Code';

  @override
  String get league => 'League';

  @override
  String get allLeaguesName => 'All leagues';

  @override
  String get exclusive => 'exclusive';

  @override
  String get inviteWhatsapp => 'Invite via WhatsApp';

  @override
  String codeCopied(String code) {
    return 'Code copied: $code';
  }

  @override
  String whatsappInvite(String groupName, String code) {
    return 'I invite you to play in my Footrix group \"$groupName\".\nGroup code: $code\nOpen Footrix > Groups > Join group and paste the code.';
  }

  @override
  String get rankingsTitle => 'Rankings';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get type => 'Type:';

  @override
  String get combined => 'Combined';

  @override
  String get worldwide => 'Worldwide';

  @override
  String get province => 'State';

  @override
  String get filterHint => 'Filter...';

  @override
  String get noDataForLeague => 'No data for this league';

  @override
  String get noUsersForFilter => 'No users for this filter';

  @override
  String get noLocation => 'No location';

  @override
  String pointsSuffix(int points) {
    return '$points pts';
  }

  @override
  String get adminPanel => 'Admin Panel';

  @override
  String get noAdminPermission => 'You do not have admin permissions';

  @override
  String get syncFifa => 'Sync FIFA';

  @override
  String get users => 'Users';

  @override
  String get createMatch => 'Create Match';

  @override
  String get finish => 'Finish';

  @override
  String fifaSynced(int matches, int leagues) {
    return 'FIFA synced: $matches matches, $leagues leagues';
  }

  @override
  String get syncFifaError => 'Error syncing FIFA';

  @override
  String get predictionSettings => 'Predictions';

  @override
  String get predictionLockLabel => 'Close predictions X hours before';

  @override
  String get predictionLockHelper => 'Use 0 to accept predictions until kickoff.';

  @override
  String get triviaSettings => 'Trivia';

  @override
  String get triviaDailyLimitLabel => 'Questions per user per day';

  @override
  String get saveSettings => 'Save settings';

  @override
  String get checkNumericValues => 'Check the numeric values';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get homeTeam => 'Home Team';

  @override
  String get awayTeam => 'Away Team';

  @override
  String get phaseExample => 'Phase (E.g. Group A)';

  @override
  String get dateTimeFormat => 'Date and Time (YYYY-MM-DD HH:MM)';

  @override
  String get lockPredictionsBefore => 'Lock predictions X hours before';

  @override
  String hoursBefore(int hours) {
    return '$hours hours before';
  }

  @override
  String get matchCreated => 'Match created';

  @override
  String get dateFormatError => 'Error: Incorrect date format';

  @override
  String get finishMatch => 'Finish Match';

  @override
  String get homeGoals => 'Home Goals';

  @override
  String get awayGoals => 'Away Goals';

  @override
  String get noPendingMatches => 'No pending matches';

  @override
  String get noSchedule => 'No schedule';

  @override
  String get footballTrivia => 'Football Trivia';

  @override
  String get noQuestionsAvailable => 'No questions available';

  @override
  String secondsLeft(int seconds) {
    return '$seconds seconds';
  }

  @override
  String get timeUp => 'Time up';

  @override
  String get alreadyAnsweredQuestion => 'You had already answered this question';

  @override
  String correctPoints(int points) {
    return 'Correct: +$points pts';
  }

  @override
  String get incorrect => 'Incorrect';

  @override
  String get nextQuestion => 'Next question';

  @override
  String get moreOptions => 'More options';

  @override
  String get past => 'Past';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get more => 'More';

  @override
  String get noPastMatches => 'No past matches for your leagues.';

  @override
  String get noMatchesToday => 'No matches today.';

  @override
  String get noMatchesTomorrow => 'No matches tomorrow.';

  @override
  String get noMatchesDate => 'No matches for this date.';

  @override
  String get noMoreMatches => 'No more loaded matches.';

  @override
  String get unableLoadFixture => 'Could not load the fixture.';

  @override
  String get live => 'Live';

  @override
  String get otherTournaments => 'Other tournaments';

  @override
  String get detail => 'Detail';

  @override
  String get matchLocked => 'Match locked';

  @override
  String get homeShort => 'Home';

  @override
  String get awayShort => 'Away';

  @override
  String get sendPrediction => 'Send Prediction';

  @override
  String get finished => 'FINISHED';

  @override
  String get yourPrediction => 'Your prediction:';

  @override
  String get closedBefore => 'Closed 12h before';

  @override
  String get notAuthenticated => 'Not authenticated';

  @override
  String get saved => 'Saved';

  @override
  String get dateTba => 'Date TBA';

  @override
  String get inPlay => 'In play';

  @override
  String todayAt(String time) {
    return 'Today $time';
  }

  @override
  String get dateToBeConfirmed => 'Date to be confirmed';

  @override
  String localDeviceTime(String date, String zone) {
    return '$date - device local time ($zone)';
  }
}
