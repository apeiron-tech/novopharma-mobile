import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/utils/auth_error_handler.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final error = await authProvider.sendPasswordResetEmail(
        _emailController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (error == null) {
          setState(() {
            _emailSent = true;
          });
        } else {
          // ... (in _sendResetEmail)
          final errorMessage = AuthErrorHandler.getErrorMessage(context, error);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: AppColors.coralDeep,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: GlassFormTheme(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Entrance(
                            offset: const Offset(0, -10),
                            child: Row(
                              children: [
                                GlassIconButton(
                                  icon: Icons.arrow_back_rounded,
                                  tooltip: MaterialLocalizations.of(context)
                                      .backButtonTooltip,
                                  onTap: () => Navigator.pop(context),
                                ),
                                const Spacer(),
                                const BrandLogo(height: 34),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                          if (!_emailSent)
                            ..._buildRequest(l10n)
                          else
                            ..._buildSent(l10n),
                        ],
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

  /// Ask for the address the link should go to.
  List<Widget> _buildRequest(AppLocalizations l10n) {
    final soft = Colors.white.withValues(alpha: 0.76);
    return [
      Entrance(
        delay: const Duration(milliseconds: 80),
        child: Text(
          l10n.resetPassword,
          maxLines: 3,
          style: AppText.display(
            size: 36,
            weight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Entrance(
        delay: const Duration(milliseconds: 140),
        child: Text(
          l10n.resetPasswordInstructions,
          style: AppText.body(size: 15.5, color: soft),
        ),
      ),
      const SizedBox(height: 28),
      Entrance(
        delay: const Duration(milliseconds: 220),
        offset: const Offset(0, 40),
        child: Glass(
          style: GlassStyle.dark,
          blur: Glass.frost,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    l10n.emailAddress,
                    style: AppText.label(
                      size: 13.5,
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
                  ),
                ),
                TextFormField(
                  controller: _emailController,
                  style: GlassFormTheme.fieldText,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'Enter your email',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return l10n.emailRequiredError;
                    }
                    if (!RegExp(
                      r'^[^@]+@[^@]+\.[^@]+',
                    ).hasMatch(value!)) {
                      return l10n.emailValidError;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      // Outside the card so the long French label has the full width.
      Entrance(
        delay: const Duration(milliseconds: 300),
        child: PrimaryButton.mint(
          label: l10n.sendResetLink,
          loading: _isLoading,
          onPressed: _sendResetEmail,
        ),
      ),
      const SizedBox(height: 24),
      // Help text
      Entrance(
        delay: const Duration(milliseconds: 360),
        child: Column(
          children: [
            Text(
              'Didn\'t receive the email? Check your spam folder or',
              textAlign: TextAlign.center,
              style: AppText.body(size: 13.5, color: soft),
            ),
            TextButton(
              onPressed: () {
                // Handle contact support
              },
              child: Text(
                'contact support',
                style: AppText.body(
                  size: 13.5,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ).copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// The link is on its way: say so, and where it went.
  List<Widget> _buildSent(AppLocalizations l10n) {
    return [
      Entrance(
        key: const ValueKey('sent'),
        offset: const Offset(0, 40),
        child: Glass(
          style: GlassStyle.dark,
          blur: Glass.frost,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Entrance(
                delay: Duration(milliseconds: 180),
                offset: Offset.zero,
                scaleFrom: 0.5,
                child: BlisterIcon(
                  icon: Icons.mark_email_read_rounded,
                  tone: Tone.mint,
                  size: 84,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                l10n.checkYourEmail,
                style: AppText.display(
                  size: 30,
                  weight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.passwordResetLinkSent,
                style: AppText.body(
                  size: 15,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _emailController.text,
                style: AppText.body(
                  size: 16,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.passwordResetExpiration,
                style: AppText.body(
                  size: 13.5,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.76),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      // Resend Button
      SecondaryButton(
        label: l10n.sendAgain,
        icon: Icons.refresh_rounded,
        onDark: true,
        height: 56,
        onPressed: () {
          setState(() {
            _emailSent = false;
          });
        },
      ),
      const SizedBox(height: 10),
      // Back to Login
      Center(
        child: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.backToSignIn),
        ),
      ),
    ];
  }
}
