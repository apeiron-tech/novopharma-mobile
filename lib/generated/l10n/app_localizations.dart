import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

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
    Locale('fr'),
  ];

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @signInToAccessAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access your account'**
  String get signInToAccessAccount;

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

  /// No description provided for @rememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberMe;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @dontHaveAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get dontHaveAnAccount;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @joinCommunity.
  ///
  /// In en, this message translates to:
  /// **'Join the pharmacy rewards community'**
  String get joinCommunity;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirth;

  /// No description provided for @yourPharmacy.
  ///
  /// In en, this message translates to:
  /// **'Your Pharmacy'**
  String get yourPharmacy;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @agreeToTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms of Service and Privacy Policy'**
  String get agreeToTerms;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @selectYourPharmacy.
  ///
  /// In en, this message translates to:
  /// **'Select your pharmacy'**
  String get selectYourPharmacy;

  /// No description provided for @pleaseSelectPharmacy.
  ///
  /// In en, this message translates to:
  /// **'Please select a pharmacy'**
  String get pleaseSelectPharmacy;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// No description provided for @resetPasswordInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we\'ll send you a link to reset your password.'**
  String get resetPasswordInstructions;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// No description provided for @checkYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Check Your Email'**
  String get checkYourEmail;

  /// No description provided for @passwordResetLinkSent.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a password reset link to:'**
  String get passwordResetLinkSent;

  /// No description provided for @passwordResetExpiration.
  ///
  /// In en, this message translates to:
  /// **'Check your email and click the link to reset your password. The link will expire in 24 hours.'**
  String get passwordResetExpiration;

  /// No description provided for @sendAgain.
  ///
  /// In en, this message translates to:
  /// **'Send Again'**
  String get sendAgain;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to Sign In'**
  String get backToSignIn;

  /// No description provided for @accountPendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Account Pending Approval'**
  String get accountPendingApproval;

  /// No description provided for @accountPendingApprovalMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account has been created successfully and is waiting for an administrator to approve it. Please check back later.'**
  String get accountPendingApprovalMessage;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @totalPoints.
  ///
  /// In en, this message translates to:
  /// **'TOTAL POINTS'**
  String get totalPoints;

  /// No description provided for @currentBalance.
  ///
  /// In en, this message translates to:
  /// **'current balance'**
  String get currentBalance;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// No description provided for @rank.
  ///
  /// In en, this message translates to:
  /// **'RANK'**
  String get rank;

  /// No description provided for @badges.
  ///
  /// In en, this message translates to:
  /// **'BADGES'**
  String get badges;

  /// No description provided for @challenges.
  ///
  /// In en, this message translates to:
  /// **'CHALLENGES'**
  String get challenges;

  /// No description provided for @goals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goals;

  /// No description provided for @weeklyQuiz.
  ///
  /// In en, this message translates to:
  /// **'Weekly Quiz'**
  String get weeklyQuiz;

  /// No description provided for @testYourKnowledge.
  ///
  /// In en, this message translates to:
  /// **'Test your pharmaceutical knowledge'**
  String get testYourKnowledge;

  /// No description provided for @takeQuiz.
  ///
  /// In en, this message translates to:
  /// **'Take Quiz'**
  String get takeQuiz;

  /// No description provided for @activeGoals.
  ///
  /// In en, this message translates to:
  /// **'Active Goals'**
  String get activeGoals;

  /// No description provided for @noActiveGoals.
  ///
  /// In en, this message translates to:
  /// **'No active goals yet'**
  String get noActiveGoals;

  /// No description provided for @checkBackSoon.
  ///
  /// In en, this message translates to:
  /// **'Check back soon for new goals!'**
  String get checkBackSoon;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @progressDetails.
  ///
  /// In en, this message translates to:
  /// **'Progress Details'**
  String get progressDetails;

  /// No description provided for @viewRules.
  ///
  /// In en, this message translates to:
  /// **'View Rules'**
  String get viewRules;

  /// No description provided for @trackProgress.
  ///
  /// In en, this message translates to:
  /// **'Track Progress'**
  String get trackProgress;

  /// No description provided for @leaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboard;

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

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @yourRank.
  ///
  /// In en, this message translates to:
  /// **'YOUR RANK'**
  String get yourRank;

  /// No description provided for @outOfEmployees.
  ///
  /// In en, this message translates to:
  /// **'out of {count} employees'**
  String outOfEmployees(Object count);

  /// No description provided for @topPerformers.
  ///
  /// In en, this message translates to:
  /// **'TOP PERFORMERS'**
  String get topPerformers;

  /// No description provided for @allEmployees.
  ///
  /// In en, this message translates to:
  /// **'ALL EMPLOYEES'**
  String get allEmployees;

  /// No description provided for @myPersonalDetails.
  ///
  /// In en, this message translates to:
  /// **'My personal details'**
  String get myPersonalDetails;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @updateProfile.
  ///
  /// In en, this message translates to:
  /// **'Update Profile'**
  String get updateProfile;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @rewardsAndRedeem.
  ///
  /// In en, this message translates to:
  /// **'Rewards & Redeem'**
  String get rewardsAndRedeem;

  /// No description provided for @allTimeRewardPoints.
  ///
  /// In en, this message translates to:
  /// **'All time reward points earned: {points}'**
  String allTimeRewardPoints(Object points);

  /// No description provided for @viewRewardPointsHistory.
  ///
  /// In en, this message translates to:
  /// **'View reward points history'**
  String get viewRewardPointsHistory;

  /// No description provided for @redeemYourPoints.
  ///
  /// In en, this message translates to:
  /// **'Redeem your points'**
  String get redeemYourPoints;

  /// No description provided for @noRewardsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No rewards available'**
  String get noRewardsAvailable;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @redeem.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get redeem;

  /// No description provided for @scanBarcodeHere.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode here'**
  String get scanBarcodeHere;

  /// No description provided for @scannedProduct.
  ///
  /// In en, this message translates to:
  /// **'Scanned Product'**
  String get scannedProduct;

  /// No description provided for @productDetailsAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Product details will appear here.'**
  String get productDetailsAppearHere;

  /// No description provided for @saleDetails.
  ///
  /// In en, this message translates to:
  /// **'Sale Details'**
  String get saleDetails;

  /// No description provided for @availableStock.
  ///
  /// In en, this message translates to:
  /// **'Available Stock'**
  String get availableStock;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @totalPrice.
  ///
  /// In en, this message translates to:
  /// **'Total Price'**
  String get totalPrice;

  /// No description provided for @protocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get protocol;

  /// No description provided for @activeCampaigns.
  ///
  /// In en, this message translates to:
  /// **'Active Campaigns'**
  String get activeCampaigns;

  /// No description provided for @relatedGoals.
  ///
  /// In en, this message translates to:
  /// **'Related Goals'**
  String get relatedGoals;

  /// No description provided for @recommendedWith.
  ///
  /// In en, this message translates to:
  /// **'Recommended With'**
  String get recommendedWith;

  /// No description provided for @confirmSale.
  ///
  /// In en, this message translates to:
  /// **'Confirm Sale'**
  String get confirmSale;

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock'**
  String get outOfStock;

  /// No description provided for @salesHistory.
  ///
  /// In en, this message translates to:
  /// **'Sales History'**
  String get salesHistory;

  /// No description provided for @noSalesRecorded.
  ///
  /// In en, this message translates to:
  /// **'No sales recorded in this period.'**
  String get noSalesRecorded;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start:'**
  String get start;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End:'**
  String get end;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navChallenges.
  ///
  /// In en, this message translates to:
  /// **'Challenges'**
  String get navChallenges;

  /// No description provided for @navLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get navLeaderboard;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @welcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get welcomeMessage;

  /// No description provided for @welcomeUser.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}!'**
  String welcomeUser(Object name);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @mon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get mon;

  /// No description provided for @tue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get tue;

  /// No description provided for @wed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get wed;

  /// No description provided for @thu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get thu;

  /// No description provided for @fri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get fri;

  /// No description provided for @sat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get sat;

  /// No description provided for @sun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sun;

  /// No description provided for @availableQuizzes.
  ///
  /// In en, this message translates to:
  /// **'Available Quizzes'**
  String get availableQuizzes;

  /// No description provided for @noQuizzesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No Quizzes Available'**
  String get noQuizzesAvailable;

  /// No description provided for @questions.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get questions;

  /// No description provided for @startQuiz.
  ///
  /// In en, this message translates to:
  /// **'Start Quiz'**
  String get startQuiz;

  /// No description provided for @quizzes.
  ///
  /// In en, this message translates to:
  /// **'Quizzes'**
  String get quizzes;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @goalDetails.
  ///
  /// In en, this message translates to:
  /// **'Goal Details'**
  String get goalDetails;

  /// No description provided for @eligibilityCriteria.
  ///
  /// In en, this message translates to:
  /// **'Eligibility Criteria'**
  String get eligibilityCriteria;

  /// No description provided for @eligibleProducts.
  ///
  /// In en, this message translates to:
  /// **'Eligible Products'**
  String get eligibleProducts;

  /// No description provided for @eligibleBrands.
  ///
  /// In en, this message translates to:
  /// **'Eligible Brands'**
  String get eligibleBrands;

  /// No description provided for @eligibleCategories.
  ///
  /// In en, this message translates to:
  /// **'Eligible Categories'**
  String get eligibleCategories;

  /// No description provided for @eligibleZones.
  ///
  /// In en, this message translates to:
  /// **'Eligible Zones'**
  String get eligibleZones;

  /// No description provided for @eligibleClientCategories.
  ///
  /// In en, this message translates to:
  /// **'Eligible Client Categories'**
  String get eligibleClientCategories;

  /// No description provided for @eligiblePharmacies.
  ///
  /// In en, this message translates to:
  /// **'Eligible Pharmacies'**
  String get eligiblePharmacies;

  /// No description provided for @noSpecificCriteria.
  ///
  /// In en, this message translates to:
  /// **'This goal applies to all sales.'**
  String get noSpecificCriteria;

  /// The number of active goals displayed in the header
  ///
  /// In en, this message translates to:
  /// **'You have {count} active goals'**
  String activeGoalsCount(int count);

  /// No description provided for @endsInDays.
  ///
  /// In en, this message translates to:
  /// **'Ends in {count}d'**
  String endsInDays(int count);

  /// No description provided for @endsInHours.
  ///
  /// In en, this message translates to:
  /// **'Ends in {count}h'**
  String endsInHours(int count);

  /// No description provided for @endsInMinutes.
  ///
  /// In en, this message translates to:
  /// **'Ends in {count}m'**
  String endsInMinutes(int count);

  /// No description provided for @endingSoon.
  ///
  /// In en, this message translates to:
  /// **'Ending soon'**
  String get endingSoon;

  /// The amount of stock available
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{{count} piece} other{{count} pieces}}'**
  String stockAmount(int count);
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
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
