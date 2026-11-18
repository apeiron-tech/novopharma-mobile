import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/design/design.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const AuroraBackground(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, viewport) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          (viewport.maxHeight - 32).clamp(0.0, double.infinity),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Entrance(
                              offset: Offset(0, -10),
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: BrandLogo(height: 38),
                              ),
                            ),
                            const SizedBox(height: 44),
                            Entrance(
                              delay: const Duration(milliseconds: 80),
                              child: Text(
                                l10n.accountPendingApproval,
                                maxLines: 3,
                                style: AppText.display(
                                  size: 34,
                                  weight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Entrance(
                              delay: const Duration(milliseconds: 180),
                              offset: const Offset(0, 40),
                              child: Glass(
                                style: GlassStyle.dark,
                                blur: Glass.frost,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.xl),
                                padding:
                                    const EdgeInsets.fromLTRB(22, 24, 22, 26),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const BlisterIcon(
                                      icon: Icons.hourglass_top_rounded,
                                      tone: Tone.amber,
                                      size: 64,
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      l10n.accountPendingApprovalMessage,
                                      style: AppText.body(
                                        size: 16,
                                        height: 1.5,
                                        color: Colors.white
                                            .withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Entrance(
                              delay: const Duration(milliseconds: 280),
                              child: SecondaryButton(
                                label: l10n.logOut,
                                icon: Icons.logout_rounded,
                                onDark: true,
                                height: 56,
                                onPressed: () => authProvider.signOut(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
