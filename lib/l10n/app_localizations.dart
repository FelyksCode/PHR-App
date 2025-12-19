import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'PHR App'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @vitalSigns.
  ///
  /// In en, this message translates to:
  /// **'Vital Signs'**
  String get vitalSigns;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

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

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noData;

  /// No description provided for @welcomeReminders.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Reminders!'**
  String get welcomeReminders;

  /// No description provided for @welcomeRemindersDesc.
  ///
  /// In en, this message translates to:
  /// **'Set reminders to track your vital signs regularly'**
  String get welcomeRemindersDesc;

  /// No description provided for @createReminder.
  ///
  /// In en, this message translates to:
  /// **'Create a Reminder'**
  String get createReminder;

  /// No description provided for @createReminderDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button in the top right to add a new reminder'**
  String get createReminderDesc;

  /// No description provided for @swipeRightToggle.
  ///
  /// In en, this message translates to:
  /// **'Swipe Right to Toggle'**
  String get swipeRightToggle;

  /// No description provided for @swipeRightToggleDesc.
  ///
  /// In en, this message translates to:
  /// **'Swipe right on a reminder to enable or disable it'**
  String get swipeRightToggleDesc;

  /// No description provided for @swipeLeftDelete.
  ///
  /// In en, this message translates to:
  /// **'Swipe Left to Delete'**
  String get swipeLeftDelete;

  /// No description provided for @swipeLeftDeleteDesc.
  ///
  /// In en, this message translates to:
  /// **'Swipe left on a reminder to delete it permanently'**
  String get swipeLeftDeleteDesc;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @tutorial.
  ///
  /// In en, this message translates to:
  /// **'Tutorial'**
  String get tutorial;

  /// No description provided for @addReminder.
  ///
  /// In en, this message translates to:
  /// **'Add Reminder'**
  String get addReminder;

  /// No description provided for @noRemindersYet.
  ///
  /// In en, this message translates to:
  /// **'No reminders yet.'**
  String get noRemindersYet;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @selectVitalSign.
  ///
  /// In en, this message translates to:
  /// **'Select Vital Sign'**
  String get selectVitalSign;

  /// No description provided for @selectInterval.
  ///
  /// In en, this message translates to:
  /// **'Select Interval'**
  String get selectInterval;

  /// No description provided for @interval.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get interval;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @dateOfMonth.
  ///
  /// In en, this message translates to:
  /// **'Date of Month'**
  String get dateOfMonth;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @pickTime.
  ///
  /// In en, this message translates to:
  /// **'Pick Time'**
  String get pickTime;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @bodyWeight.
  ///
  /// In en, this message translates to:
  /// **'Body Weight'**
  String get bodyWeight;

  /// No description provided for @bodyHeight.
  ///
  /// In en, this message translates to:
  /// **'Body Height'**
  String get bodyHeight;

  /// No description provided for @bodyTemperature.
  ///
  /// In en, this message translates to:
  /// **'Body Temperature'**
  String get bodyTemperature;

  /// No description provided for @heartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get heartRate;

  /// No description provided for @bloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Blood Pressure'**
  String get bloodPressure;

  /// No description provided for @oxygenSaturation.
  ///
  /// In en, this message translates to:
  /// **'Oxygen Saturation'**
  String get oxygenSaturation;

  /// No description provided for @trackWeight.
  ///
  /// In en, this message translates to:
  /// **'Track your weight changes'**
  String get trackWeight;

  /// No description provided for @recordHeight.
  ///
  /// In en, this message translates to:
  /// **'Record your height measurement'**
  String get recordHeight;

  /// No description provided for @monitorTemperature.
  ///
  /// In en, this message translates to:
  /// **'Monitor body temperature'**
  String get monitorTemperature;

  /// No description provided for @trackHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Track your heart rate'**
  String get trackHeartRate;

  /// No description provided for @recordBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Record systolic and diastolic BP'**
  String get recordBloodPressure;

  /// No description provided for @monitorOxygen.
  ///
  /// In en, this message translates to:
  /// **'Monitor blood oxygen levels'**
  String get monitorOxygen;

  /// No description provided for @languageSettings.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSettings;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @indonesian.
  ///
  /// In en, this message translates to:
  /// **'Indonesian (Bahasa Indonesia)'**
  String get indonesian;

  /// No description provided for @healthReminders.
  ///
  /// In en, this message translates to:
  /// **'Health Reminders'**
  String get healthReminders;

  /// No description provided for @enableReminders.
  ///
  /// In en, this message translates to:
  /// **'Enable reminders'**
  String get enableReminders;

  /// No description provided for @enableRemindersDesc.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications to remind you to record vital signs.'**
  String get enableRemindersDesc;

  /// No description provided for @vibrate.
  ///
  /// In en, this message translates to:
  /// **'Vibrate'**
  String get vibrate;

  /// No description provided for @vibrateDesc.
  ///
  /// In en, this message translates to:
  /// **'Use vibration for reminder notifications.'**
  String get vibrateDesc;

  /// No description provided for @syncSettings.
  ///
  /// In en, this message translates to:
  /// **'Sync Settings'**
  String get syncSettings;

  /// No description provided for @dataExport.
  ///
  /// In en, this message translates to:
  /// **'Data Export'**
  String get dataExport;

  /// No description provided for @exportToPDF.
  ///
  /// In en, this message translates to:
  /// **'Export to PDF'**
  String get exportToPDF;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// No description provided for @userFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userFallback;

  /// No description provided for @lastSyncPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Last sync: -- hours ago'**
  String get lastSyncPlaceholder;

  /// No description provided for @autoLabel.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get autoLabel;

  /// No description provided for @connectionIssueMessage.
  ///
  /// In en, this message translates to:
  /// **'Make sure you have internet connection to sync with the latest update.'**
  String get connectionIssueMessage;

  /// No description provided for @fhirUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Connection to FHIR is unavailable. It will sync automatically when the service is back.'**
  String get fhirUnavailableMessage;

  /// No description provided for @healthStatistics.
  ///
  /// In en, this message translates to:
  /// **'Health Statistics'**
  String get healthStatistics;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @recorded.
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get recorded;

  /// No description provided for @reported.
  ///
  /// In en, this message translates to:
  /// **'Reported'**
  String get reported;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @conditionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get conditionsLabel;

  /// No description provided for @recordMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Record measurements'**
  String get recordMeasurements;

  /// No description provided for @reportSymptoms.
  ///
  /// In en, this message translates to:
  /// **'Report symptoms'**
  String get reportSymptoms;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal Health Record'**
  String get loginTitle;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get logIn;

  /// No description provided for @demoCredentials.
  ///
  /// In en, this message translates to:
  /// **'Demo credentials'**
  String get demoCredentials;

  /// No description provided for @demoEmail.
  ///
  /// In en, this message translates to:
  /// **'Email: john@example.com'**
  String get demoEmail;

  /// No description provided for @demoPassword.
  ///
  /// In en, this message translates to:
  /// **'Password: securepassword123'**
  String get demoPassword;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
