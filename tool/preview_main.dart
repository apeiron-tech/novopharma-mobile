// Design preview: boots the real app shell onto a menu of the signed-out
// screens, so they can be reviewed without signing out.
//
//   flutter run -t tool/preview_main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/locale_provider.dart';
import 'package:novopharma/firebase_options.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:novopharma/screens/forgot_password_screen.dart';
import 'package:novopharma/screens/introduction_screen_custom.dart';
import 'package:novopharma/screens/login_screen.dart';
import 'package:novopharma/screens/pending_approval_screen.dart';
import 'package:novopharma/screens/signup_screen.dart';
import 'package:novopharma/screens/splash_screen.dart';
import 'package:novopharma/theme.dart';
import 'package:novopharma/widgets/terms_conditions_modal.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Provider.of<LocaleProvider>(context).locale,
          home: const _Menu(),
        ),
      ),
    ),
  );
}

class _Menu extends StatelessWidget {
  const _Menu();

  @override
  Widget build(BuildContext context) {
    final screens = <String, WidgetBuilder>{
      'Splash': (_) => const SplashScreen(),
      'Onboarding': (_) => const IntroductionScreenCustom(),
      'Login': (_) => const LoginScreen(),
      'Sign up': (_) => const SignupScreen(),
      'Forgot password': (_) => const ForgotPasswordScreen(),
      'Pending approval': (_) => const PendingApprovalScreen(),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Design preview')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final entry in screens.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: entry.value),
                ),
                child: Text(entry.key),
              ),
            ),
          FilledButton.tonal(
            onPressed: () => TermsConditionsModal.show(context),
            child: const Text('Terms sheet'),
          ),
        ],
      ),
    );
  }
}
