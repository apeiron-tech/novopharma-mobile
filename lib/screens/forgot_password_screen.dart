import 'package:flutter/material.dart';
import 'package:novopharma/theme.dart';
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
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: LightModeColors.dashboardTextPrimary,
              size: 16,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                if (!_emailSent) ...[
                  // Reset Password Header
                  Text(
                    l10n.resetPassword,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: LightModeColors.dashboardTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.resetPasswordInstructions,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: LightModeColors.novoPharmaGray,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Reset Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.emailAddress,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: LightModeColors.dashboardTextPrimary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Enter your email',
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: LightModeColors.novoPharmaGray,
                            ),
                            filled: true,
                            fillColor: LightModeColors.lightSurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: LightModeColors.lightOutline,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: LightModeColors.lightOutline,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: LightModeColors.lightPrimary,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
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

                  const SizedBox(height: 40),

                  // Send Reset Link Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendResetEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LightModeColors.lightPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              l10n.sendResetLink,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                            ),
                    ),
                  ),
                ] else ...[
                  // Email Sent Success State
                  const SizedBox(height: 40),

                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: LightModeColors.novoPharmaBlue.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(60),
                          ),
                          child: const Icon(
                            Icons.email_outlined,
                            size: 60,
                            color: LightModeColors.novoPharmaBlue,
                          ),
                        ),

                        const SizedBox(height: 32),

                        Text(
                          l10n.checkYourEmail,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: LightModeColors.dashboardTextPrimary,
                              ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          l10n.passwordResetLinkSent,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: LightModeColors.novoPharmaGray),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          _emailController.text,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                        ),

                        const SizedBox(height: 24),

                        Text(
                          l10n.passwordResetExpiration,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: LightModeColors.novoPharmaGray,
                                height: 1.5,
                              ),
                        ),

                        const SizedBox(height: 40),

                        // Resend Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _emailSent = false;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: LightModeColors.novoPharmaBlue,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              l10n.sendAgain,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: LightModeColors.novoPharmaBlue,
                                  ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Back to Login
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            l10n.backToSignIn,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: LightModeColors.novoPharmaBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                // Help text
                if (!_emailSent)
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Didn\'t receive the email? Check your spam folder or',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: LightModeColors.novoPharmaGray),
                        ),
                        TextButton(
                          onPressed: () {
                            // Handle contact support
                          },
                          child: Text(
                            'contact support',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: LightModeColors.novoPharmaBlue,
                                  decoration: TextDecoration.underline,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
