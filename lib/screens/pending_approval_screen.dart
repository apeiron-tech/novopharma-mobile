import 'package:flutter/material.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/theme.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: LightModeColors.novoPharmaLightBlue,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: Image.asset('assets/images/logo.png'),
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.accountPendingApproval,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: LightModeColors.dashboardTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.accountPendingApprovalMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: LightModeColors.dashboardTextSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => authProvider.signOut(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LightModeColors.novoPharmaBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      l10n.logOut,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
