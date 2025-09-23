import 'package:flutter/material.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/screens/dashboard_home_screen.dart';
import 'package:novopharma/screens/login_screen.dart';
import 'package:novopharma/screens/pending_approval_screen.dart';
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
      case AppAuthState.authenticatedDisabled: // Kicking disabled users back to login
        return const LoginScreen();
      case AppAuthState.unknown:
      default:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
    }
  }
}

