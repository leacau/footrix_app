import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Footrix'**
  String get appTitle;

  /// No description provided for @loginWelcome.
  ///
  /// In en, this message translates to:
  /// **'Predict. Compete. Climb.'**
  String get loginWelcome;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailHint;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginButton;

  /// No description provided for @googleLogin.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get googleLogin;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccount;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccount;

  /// No description provided for @incorrectCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password'**
  String get incorrectCredentials;

  /// No description provided for @emailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered'**
  String get emailAlreadyInUse;

  /// No description provided for @errorRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get errorRequired;

  /// No description provided for @errorEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get errorEmail;

  /// No description provided for @errorPassword.
  ///
  /// In en, this message translates to:
  /// **'Min 6 characters'**
  String get errorPassword;

  /// No description provided for @errorAuth.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorAuth(String error);

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @fixture.
  ///
  /// In en, this message translates to:
  /// **'Fixture'**
  String get fixture;

  /// No description provided for @trivia.
  ///
  /// In en, this message translates to:
  /// **'Trivia'**
  String get trivia;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @rankings.
  ///
  /// In en, this message translates to:
  /// **'Rankings'**
  String get rankings;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @spanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get spanish;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @languageChanged.
  ///
  /// In en, this message translates to:
  /// **'Language: {language}'**
  String languageChanged(String language);

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @enablePush.
  ///
  /// In en, this message translates to:
  /// **'Enable push'**
  String get enablePush;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @allLeagues.
  ///
  /// In en, this message translates to:
  /// **'All leagues'**
  String get allLeagues;

  /// No description provided for @noName.
  ///
  /// In en, this message translates to:
  /// **'No name'**
  String get noName;

  /// No description provided for @unnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed'**
  String get unnamed;

  /// No description provided for @anonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get anonymous;

  /// No description provided for @unspecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get unspecified;

  /// No description provided for @helloUser.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}!'**
  String helloUser(String name);

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @chooseSection.
  ///
  /// In en, this message translates to:
  /// **'Choose a section to start:'**
  String get chooseSection;

  /// No description provided for @fixtureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Predict matches'**
  String get fixtureSubtitle;

  /// No description provided for @triviaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quick questions'**
  String get triviaSubtitle;

  /// No description provided for @groupsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Compete with friends'**
  String get groupsSubtitle;

  /// No description provided for @rankingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get rankingsSubtitle;

  /// No description provided for @profileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'My data and stats'**
  String get profileSubtitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Language, notifications'**
  String get settingsSubtitle;

  /// No description provided for @adminSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get adminSubtitle;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @myStats.
  ///
  /// In en, this message translates to:
  /// **'Your Stats'**
  String get myStats;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streak;

  /// No description provided for @leaguesToPlay.
  ///
  /// In en, this message translates to:
  /// **'Leagues to play'**
  String get leaguesToPlay;

  /// No description provided for @leaguesSaved.
  ///
  /// In en, this message translates to:
  /// **'Leagues saved'**
  String get leaguesSaved;

  /// No description provided for @noLeagueSelection.
  ///
  /// In en, this message translates to:
  /// **'No selection: all leagues for the day are shown.'**
  String get noLeagueSelection;

  /// No description provided for @selectedLeagueCount.
  ///
  /// In en, this message translates to:
  /// **'{count} leagues selected'**
  String selectedLeagueCount(int count);

  /// No description provided for @errorLoadingLeagues.
  ///
  /// In en, this message translates to:
  /// **'Error loading leagues'**
  String get errorLoadingLeagues;

  /// No description provided for @predictions.
  ///
  /// In en, this message translates to:
  /// **'Predictions'**
  String get predictions;

  /// No description provided for @totalPoints.
  ///
  /// In en, this message translates to:
  /// **'Total points'**
  String get totalPoints;

  /// No description provided for @triviaPoints.
  ///
  /// In en, this message translates to:
  /// **'Trivia points'**
  String get triviaPoints;

  /// No description provided for @currentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current streak'**
  String get currentStreak;

  /// No description provided for @bestStreak.
  ///
  /// In en, this message translates to:
  /// **'Best streak'**
  String get bestStreak;

  /// No description provided for @answeredQuestions.
  ///
  /// In en, this message translates to:
  /// **'Answered questions'**
  String get answeredQuestions;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @provinceState.
  ///
  /// In en, this message translates to:
  /// **'State/Province'**
  String get provinceState;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @myGroups.
  ///
  /// In en, this message translates to:
  /// **'My Groups'**
  String get myGroups;

  /// No description provided for @createGroup.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get createGroup;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group Name'**
  String get groupName;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'E.g. Office, Family, Friends'**
  String get groupNameHint;

  /// No description provided for @leagueCompetition.
  ///
  /// In en, this message translates to:
  /// **'League/Competition:'**
  String get leagueCompetition;

  /// No description provided for @onlyThisLeague.
  ///
  /// In en, this message translates to:
  /// **'Only this league'**
  String get onlyThisLeague;

  /// No description provided for @leagueExclusiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The ranking will only count matches from the selected league'**
  String get leagueExclusiveSubtitle;

  /// No description provided for @groupCreated.
  ///
  /// In en, this message translates to:
  /// **'Group created'**
  String get groupCreated;

  /// No description provided for @selectLeagueWarning.
  ///
  /// In en, this message translates to:
  /// **'Select a league to continue'**
  String get selectLeagueWarning;

  /// No description provided for @joinGroup.
  ///
  /// In en, this message translates to:
  /// **'Join Group'**
  String get joinGroup;

  /// No description provided for @sixCharacterCode.
  ///
  /// In en, this message translates to:
  /// **'6-character code'**
  String get sixCharacterCode;

  /// No description provided for @codeExample.
  ///
  /// In en, this message translates to:
  /// **'E.g. X7K9P2'**
  String get codeExample;

  /// No description provided for @joinedGroup.
  ///
  /// In en, this message translates to:
  /// **'You joined the group'**
  String get joinedGroup;

  /// No description provided for @noGroupsYet.
  ///
  /// In en, this message translates to:
  /// **'You do not belong to any group yet.'**
  String get noGroupsYet;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get code;

  /// No description provided for @league.
  ///
  /// In en, this message translates to:
  /// **'League'**
  String get league;

  /// No description provided for @allLeaguesName.
  ///
  /// In en, this message translates to:
  /// **'All leagues'**
  String get allLeaguesName;

  /// No description provided for @exclusive.
  ///
  /// In en, this message translates to:
  /// **'exclusive'**
  String get exclusive;

  /// No description provided for @inviteWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Invite via WhatsApp'**
  String get inviteWhatsapp;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied: {code}'**
  String codeCopied(String code);

  /// No description provided for @whatsappInvite.
  ///
  /// In en, this message translates to:
  /// **'I invite you to play in my Footrix group \"{groupName}\".\nGroup code: {code}\nOpen Footrix > Groups > Join group and paste the code.'**
  String whatsappInvite(String groupName, String code);

  /// No description provided for @rankingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Rankings'**
  String get rankingsTitle;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type:'**
  String get type;

  /// No description provided for @combined.
  ///
  /// In en, this message translates to:
  /// **'Combined'**
  String get combined;

  /// No description provided for @worldwide.
  ///
  /// In en, this message translates to:
  /// **'Worldwide'**
  String get worldwide;

  /// No description provided for @province.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get province;

  /// No description provided for @filterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter...'**
  String get filterHint;

  /// No description provided for @noDataForLeague.
  ///
  /// In en, this message translates to:
  /// **'No data for this league'**
  String get noDataForLeague;

  /// No description provided for @noUsersForFilter.
  ///
  /// In en, this message translates to:
  /// **'No users for this filter'**
  String get noUsersForFilter;

  /// No description provided for @noLocation.
  ///
  /// In en, this message translates to:
  /// **'No location'**
  String get noLocation;

  /// No description provided for @pointsSuffix.
  ///
  /// In en, this message translates to:
  /// **'{points} pts'**
  String pointsSuffix(int points);

  /// No description provided for @adminPanel.
  ///
  /// In en, this message translates to:
  /// **'Admin Panel'**
  String get adminPanel;

  /// No description provided for @noAdminPermission.
  ///
  /// In en, this message translates to:
  /// **'You do not have admin permissions'**
  String get noAdminPermission;

  /// No description provided for @syncFifa.
  ///
  /// In en, this message translates to:
  /// **'Sync FIFA'**
  String get syncFifa;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @createMatch.
  ///
  /// In en, this message translates to:
  /// **'Create Match'**
  String get createMatch;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @fifaSynced.
  ///
  /// In en, this message translates to:
  /// **'FIFA synced: {matches} matches, {leagues} leagues'**
  String fifaSynced(int matches, int leagues);

  /// No description provided for @syncFifaError.
  ///
  /// In en, this message translates to:
  /// **'Error syncing FIFA'**
  String get syncFifaError;

  /// No description provided for @predictionSettings.
  ///
  /// In en, this message translates to:
  /// **'Predictions'**
  String get predictionSettings;

  /// No description provided for @predictionLockLabel.
  ///
  /// In en, this message translates to:
  /// **'Close predictions X hours before'**
  String get predictionLockLabel;

  /// No description provided for @predictionLockHelper.
  ///
  /// In en, this message translates to:
  /// **'Use 0 to accept predictions until kickoff.'**
  String get predictionLockHelper;

  /// No description provided for @triviaSettings.
  ///
  /// In en, this message translates to:
  /// **'Trivia'**
  String get triviaSettings;

  /// No description provided for @triviaDailyLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Questions per user per day'**
  String get triviaDailyLimitLabel;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
  String get saveSettings;

  /// No description provided for @checkNumericValues.
  ///
  /// In en, this message translates to:
  /// **'Check the numeric values'**
  String get checkNumericValues;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @homeTeam.
  ///
  /// In en, this message translates to:
  /// **'Home Team'**
  String get homeTeam;

  /// No description provided for @awayTeam.
  ///
  /// In en, this message translates to:
  /// **'Away Team'**
  String get awayTeam;

  /// No description provided for @phaseExample.
  ///
  /// In en, this message translates to:
  /// **'Phase (E.g. Group A)'**
  String get phaseExample;

  /// No description provided for @dateTimeFormat.
  ///
  /// In en, this message translates to:
  /// **'Date and Time (YYYY-MM-DD HH:MM)'**
  String get dateTimeFormat;

  /// No description provided for @lockPredictionsBefore.
  ///
  /// In en, this message translates to:
  /// **'Lock predictions X hours before'**
  String get lockPredictionsBefore;

  /// No description provided for @hoursBefore.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours before'**
  String hoursBefore(int hours);

  /// No description provided for @matchCreated.
  ///
  /// In en, this message translates to:
  /// **'Match created'**
  String get matchCreated;

  /// No description provided for @dateFormatError.
  ///
  /// In en, this message translates to:
  /// **'Error: Incorrect date format'**
  String get dateFormatError;

  /// No description provided for @finishMatch.
  ///
  /// In en, this message translates to:
  /// **'Finish Match'**
  String get finishMatch;

  /// No description provided for @homeGoals.
  ///
  /// In en, this message translates to:
  /// **'Home Goals'**
  String get homeGoals;

  /// No description provided for @awayGoals.
  ///
  /// In en, this message translates to:
  /// **'Away Goals'**
  String get awayGoals;

  /// No description provided for @noPendingMatches.
  ///
  /// In en, this message translates to:
  /// **'No pending matches'**
  String get noPendingMatches;

  /// No description provided for @noSchedule.
  ///
  /// In en, this message translates to:
  /// **'No schedule'**
  String get noSchedule;

  /// No description provided for @footballTrivia.
  ///
  /// In en, this message translates to:
  /// **'Football Trivia'**
  String get footballTrivia;

  /// No description provided for @noQuestionsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No questions available'**
  String get noQuestionsAvailable;

  /// No description provided for @secondsLeft.
  ///
  /// In en, this message translates to:
  /// **'{seconds} seconds'**
  String secondsLeft(int seconds);

  /// No description provided for @timeUp.
  ///
  /// In en, this message translates to:
  /// **'Time up'**
  String get timeUp;

  /// No description provided for @alreadyAnsweredQuestion.
  ///
  /// In en, this message translates to:
  /// **'You had already answered this question'**
  String get alreadyAnsweredQuestion;

  /// No description provided for @correctPoints.
  ///
  /// In en, this message translates to:
  /// **'Correct: +{points} pts'**
  String correctPoints(int points);

  /// No description provided for @incorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get incorrect;

  /// No description provided for @nextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get nextQuestion;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @past.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get past;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @noPastMatches.
  ///
  /// In en, this message translates to:
  /// **'No past matches for your leagues.'**
  String get noPastMatches;

  /// No description provided for @noMatchesToday.
  ///
  /// In en, this message translates to:
  /// **'No matches today.'**
  String get noMatchesToday;

  /// No description provided for @noMatchesTomorrow.
  ///
  /// In en, this message translates to:
  /// **'No matches tomorrow.'**
  String get noMatchesTomorrow;

  /// No description provided for @noMatchesDate.
  ///
  /// In en, this message translates to:
  /// **'No matches for this date.'**
  String get noMatchesDate;

  /// No description provided for @noMoreMatches.
  ///
  /// In en, this message translates to:
  /// **'No more loaded matches.'**
  String get noMoreMatches;

  /// No description provided for @unableLoadFixture.
  ///
  /// In en, this message translates to:
  /// **'Could not load the fixture.'**
  String get unableLoadFixture;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @otherTournaments.
  ///
  /// In en, this message translates to:
  /// **'Other tournaments'**
  String get otherTournaments;

  /// No description provided for @detail.
  ///
  /// In en, this message translates to:
  /// **'Detail'**
  String get detail;

  /// No description provided for @matchLocked.
  ///
  /// In en, this message translates to:
  /// **'Match locked'**
  String get matchLocked;

  /// No description provided for @homeShort.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeShort;

  /// No description provided for @awayShort.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get awayShort;

  /// No description provided for @sendPrediction.
  ///
  /// In en, this message translates to:
  /// **'Send Prediction'**
  String get sendPrediction;

  /// No description provided for @finished.
  ///
  /// In en, this message translates to:
  /// **'FINISHED'**
  String get finished;

  /// No description provided for @yourPrediction.
  ///
  /// In en, this message translates to:
  /// **'Your prediction:'**
  String get yourPrediction;

  /// No description provided for @closedBefore.
  ///
  /// In en, this message translates to:
  /// **'Closed 12h before'**
  String get closedBefore;

  /// No description provided for @notAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Not authenticated'**
  String get notAuthenticated;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @dateTba.
  ///
  /// In en, this message translates to:
  /// **'Date TBA'**
  String get dateTba;

  /// No description provided for @inPlay.
  ///
  /// In en, this message translates to:
  /// **'In play'**
  String get inPlay;

  /// No description provided for @todayAt.
  ///
  /// In en, this message translates to:
  /// **'Today {time}'**
  String todayAt(String time);

  /// No description provided for @dateToBeConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Date to be confirmed'**
  String get dateToBeConfirmed;

  /// No description provided for @localDeviceTime.
  ///
  /// In en, this message translates to:
  /// **'{date} - device local time ({zone})'**
  String localDeviceTime(String date, String zone);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'es': return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
