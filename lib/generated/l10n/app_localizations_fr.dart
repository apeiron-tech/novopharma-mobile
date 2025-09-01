// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get welcomeBack => 'Bon retour';

  @override
  String get signInToAccessAccount =>
      'Connectez-vous pour accéder à votre compte';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Mot de passe';

  @override
  String get rememberMe => 'Se souvenir de moi';

  @override
  String get forgotPassword => 'Mot de passe oublié?';

  @override
  String get signIn => 'Se connecter';

  @override
  String get dontHaveAnAccount => 'Vous n\'avez pas de compte? ';

  @override
  String get signUp => 'S\'inscrire';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get joinCommunity =>
      'Rejoignez la communauté des récompenses de la pharmacie';

  @override
  String get firstName => 'Prénom';

  @override
  String get lastName => 'Nom de famille';

  @override
  String get emailAddress => 'Adresse e-mail';

  @override
  String get phoneNumber => 'Numéro de téléphone';

  @override
  String get dateOfBirth => 'Date de naissance';

  @override
  String get yourPharmacy => 'Votre pharmacie';

  @override
  String get confirmPassword => 'Confirmez le mot de passe';

  @override
  String get agreeToTerms =>
      'J\'accepte les conditions d\'utilisation et la politique de confidentialité';

  @override
  String get alreadyHaveAccount => 'Vous avez déjà un compte? ';

  @override
  String get selectYourPharmacy => 'Sélectionnez votre pharmacie';

  @override
  String get pleaseSelectPharmacy => 'Veuillez sélectionner une pharmacie';

  @override
  String get resetPassword => 'Réinitialiser le mot de passe';

  @override
  String get resetPasswordInstructions =>
      'Entrez votre adresse e-mail et nous vous enverrons un lien pour réinitialiser votre mot de passe.';

  @override
  String get sendResetLink => 'Envoyer le lien de réinitialisation';

  @override
  String get checkYourEmail => 'Vérifiez votre e-mail';

  @override
  String get passwordResetLinkSent =>
      'Nous avons envoyé un lien de réinitialisation de mot de passe à :';

  @override
  String get passwordResetExpiration =>
      'Vérifiez votre e-mail et cliquez sur le lien pour réinitialiser votre mot de passe. Le lien expirera dans 24 heures.';

  @override
  String get sendAgain => 'Renvoyer';

  @override
  String get backToSignIn => 'Retour à la connexion';

  @override
  String get accountPendingApproval => 'Compte en attente d\'approbation';

  @override
  String get accountPendingApprovalMessage =>
      'Votre compte a été créé avec succès et est en attente d\'approbation par un administrateur. Veuillez revenir plus tard.';

  @override
  String get logOut => 'Se déconnecter';

  @override
  String get welcome => 'Bienvenue';

  @override
  String get totalPoints => 'POINTS TOTAUX';

  @override
  String get currentBalance => 'solde actuel';

  @override
  String get points => 'POINTS';

  @override
  String get rank => 'RANG';

  @override
  String get badges => 'BADGES';

  @override
  String get challenges => 'DÉFIS';

  @override
  String get goals => 'Objectifs';

  @override
  String get weeklyQuiz => 'Quiz de la semaine';

  @override
  String get testYourKnowledge => 'Testez vos connaissances pharmaceutiques';

  @override
  String get takeQuiz => 'Faire le quiz';

  @override
  String get exclusive => 'Exclusif';

  @override
  String get premiumGoals => 'Objectifs premium';

  @override
  String get community => 'Communauté';

  @override
  String get joinOthers => 'Rejoindre les autres';

  @override
  String get activeGoals => 'Objectifs actifs';

  @override
  String get noActiveGoals => 'Aucun objectif actif pour le moment';

  @override
  String get checkBackSoon => 'Revenez bientôt pour de nouveaux objectifs !';

  @override
  String get complete => 'Terminé';

  @override
  String get progressDetails => 'Détails de la progression';

  @override
  String get viewRules => 'Voir les règles';

  @override
  String get trackProgress => 'Suivre la progression';

  @override
  String get leaderboard => 'Classement';

  @override
  String get daily => 'Quotidien';

  @override
  String get weekly => 'Hebdo';

  @override
  String get monthly => 'Mensuel';

  @override
  String get yearly => 'Annuel';

  @override
  String get yourRank => 'VOTRE RANG';

  @override
  String outOfEmployees(Object count) {
    return 'sur $count employés';
  }

  @override
  String get topPerformers => 'MEILLEURS PERFORMANTS';

  @override
  String get allEmployees => 'TOUS LES EMPLOYÉS';

  @override
  String get myPersonalDetails => 'Mes informations personnelles';

  @override
  String get fullName => 'Nom complet';

  @override
  String get phone => 'Téléphone';

  @override
  String get updateProfile => 'Mettre à jour le profil';

  @override
  String get disconnect => 'Se déconnecter';

  @override
  String get rewardsAndRedeem => 'Récompenses et échange';

  @override
  String allTimeRewardPoints(Object points) {
    return 'Total des points de récompense gagnés : $points';
  }

  @override
  String get viewRewardPointsHistory =>
      'Voir l\'historique des points de récompense';

  @override
  String get redeemYourPoints => 'Échangez vos points';

  @override
  String get noRewardsAvailable => 'Aucune récompense disponible';

  @override
  String get cancel => 'Annuler';

  @override
  String get redeem => 'Échanger';

  @override
  String get scanBarcodeHere => 'Scannez le code-barres ici';

  @override
  String get scannedProduct => 'Produit scanné';

  @override
  String get productDetailsAppearHere =>
      'Les détails du produit apparaîtront ici.';

  @override
  String get saleDetails => 'Détails de la vente';

  @override
  String get availableStock => 'Stock disponible';

  @override
  String get quantity => 'Quantité';

  @override
  String get totalPrice => 'Prix total';

  @override
  String get protocol => 'Protocole';

  @override
  String get activeCampaigns => 'Campagnes actives';

  @override
  String get relatedGoals => 'Objectifs associés';

  @override
  String get recommendedWith => 'Recommandé avec';

  @override
  String get confirmSale => 'Confirmer la vente';

  @override
  String get outOfStock => 'En rupture de stock';

  @override
  String get salesHistory => 'Historique des ventes';

  @override
  String get noSalesRecorded => 'Aucune vente enregistrée pour cette période.';

  @override
  String get start => 'Début :';

  @override
  String get end => 'Fin :';

  @override
  String get select => 'Sélectionner';

  @override
  String get clear => 'Effacer';

  @override
  String get filter => 'Filtrer';

  @override
  String get navHome => 'Accueil';

  @override
  String get navChallenges => 'Défis';

  @override
  String get navLeaderboard => 'Classement';

  @override
  String get navHistory => 'Historique';

  @override
  String get welcomeMessage => 'Bienvenue !';

  @override
  String welcomeUser(Object name) {
    return 'Bienvenue, $name !';
  }

  @override
  String get today => 'Auj.';

  @override
  String get mon => 'Lun';

  @override
  String get tue => 'Mar';

  @override
  String get wed => 'Mer';

  @override
  String get thu => 'Jeu';

  @override
  String get fri => 'Ven';

  @override
  String get sat => 'Sam';

  @override
  String get sun => 'Dim';
}
