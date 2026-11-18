import 'package:flutter/material.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/screens/dashboard_home_screen.dart';
import 'package:novopharma/screens/login_screen.dart';
import 'package:novopharma/screens/pending_approval_screen.dart';
import 'package:novopharma/screens/introduction_screen_custom.dart';
import 'package:provider/provider.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    print('[AuthWrapper] Building with state: ${authProvider.appAuthState}');

    switch (authProvider.appAuthState) {
      case AppAuthState.authenticatedActive:
        return const DashboardHomeScreen();
      case AppAuthState.authenticatedPending:
        return const PendingApprovalScreen();
      case AppAuthState.unauthenticated:
      case AppAuthState
          .authenticatedDisabled: // Kicking disabled users back to login
        if (!authProvider.hasSeenIntro &&
            authProvider.appAuthState == AppAuthState.unauthenticated) {
          return IntroductionScreenCustom();
        }
        return const LoginScreen();
      case AppAuthState.unknown:
      default:
        // Continues the splash while the session resolves.
        return const Scaffold(
          backgroundColor: AppColors.ink,
          body: AuroraBackground(
            child: Center(
              child: CapsuleLoader(
                size: 56,
                left: Colors.white,
                right: AppColors.mint,
              ),
            ),
          ),
        );
    }
  }
}
