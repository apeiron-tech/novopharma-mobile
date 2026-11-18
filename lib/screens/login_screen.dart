import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/locale_provider.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/screens/signup_screen.dart';
import 'package:novopharma/screens/forgot_password_screen.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:novopharma/utils/auth_error_handler.dart';
import 'package:novopharma/widgets/terms_conditions_modal.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();
  late final TapGestureRecognizer _termsRecognizer = TapGestureRecognizer()
    ..onTap = () => TermsConditionsModal.show(context);
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    _termsRecognizer.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final error = await authProvider.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (error != null) {
      final errorMessage = AuthErrorHandler.getErrorMessage(context, error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.coralDeep,
        ),
      );
    }
    // No navigation code needed here, AuthWrapper handles it.
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
              child: LayoutBuilder(
                builder: (context, viewport) => SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
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
                            Entrance(
                              offset: const Offset(0, -10),
                              child: Row(
                                children: const [
                                  BrandLogo(height: 38),
                                  Spacer(),
                                  _LanguageSwitch(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 44),
                            Entrance(
                              delay: const Duration(milliseconds: 80),
                              child: Text(
                                l10n.welcomeBack,
                                maxLines: 2,
                                style: AppText.display(
                                  size: 42,
                                  weight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Entrance(
                              delay: const Duration(milliseconds: 140),
                              child: Text(
                                l10n.signInToAccessAccount,
                                style: AppText.body(
                                  size: 15.5,
                                  color: Colors.white.withValues(alpha: 0.76),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Entrance(
                              delay: const Duration(milliseconds: 220),
                              offset: const Offset(0, 40),
                              child: Glass(
                                style: GlassStyle.dark,
                                blur: Glass.frost,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.xl),
                                padding:
                                    const EdgeInsets.fromLTRB(20, 24, 20, 22),
                                child: GlassFormTheme(child: _buildForm(l10n)),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Entrance(
                              delay: const Duration(milliseconds: 320),
                              child: _buildFooter(l10n),
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

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          text,
          style: AppText.label(
            size: 13.5,
            color: Colors.white.withValues(alpha: 0.86),
          ),
        ),
      );

  Widget _buildForm(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel(l10n.email),
            TextFormField(
              controller: _emailController,
              style: GlassFormTheme.fieldText,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              decoration: const InputDecoration(
                hintText: 'prenom.nom@email.com',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return l10n.emailRequiredError;
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
                  return l10n.emailValidError;
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            _fieldLabel(l10n.password),
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              style: GlassFormTheme.fieldText,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _isLoading ? null : _handleLogin(),
              decoration: InputDecoration(
                hintText: '••••••••••••',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return l10n.passwordRequiredError;
                }
                if (value!.length < 8) {
                  return l10n.passwordLengthError;
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Pressable(
                    haptic: false,
                    pressedScale: 0.98,
                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 30,
                          height: 44,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            l10n.rememberMe,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(
                              size: 13.5,
                              weight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.86),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 44),
                    textStyle: AppText.body(size: 13.5, weight: FontWeight.w700),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: Text(l10n.forgotPassword),
                ),
              ],
            ),
            const SizedBox(height: 18),
            PrimaryButton.mint(
              label: l10n.signIn,
              icon: Icons.login_rounded,
              loading: _isLoading,
              onPressed: _handleLogin,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(AppLocalizations l10n) {
    final soft = Colors.white.withValues(alpha: 0.72);
    return Column(
      children: [
        Pressable(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SignupScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text.rich(
              TextSpan(
                style: AppText.body(size: 15, color: soft),
                children: [
                  TextSpan(text: l10n.dontHaveAnAccount),
                  TextSpan(
                    text: l10n.signUp,
                    style: AppText.body(
                      size: 15,
                      weight: FontWeight.w700,
                      color: AppColors.mintBright,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            style: AppText.body(
              size: 12.5,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            children: [
              TextSpan(text: l10n.byContinuingYouAgree),
              TextSpan(
                text: l10n.termsAndPrivacy,
                style: AppText.body(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ).copyWith(decoration: TextDecoration.underline),
                recognizer: _termsRecognizer,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// EN / FR switch on glass, with a thumb that slides to the active language.
class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch();

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        final isEnglish = localeProvider.locale?.languageCode == 'en';

        Widget option(String code, bool selected) => Expanded(
              child: Pressable(
                pressedScale: 0.94,
                semanticLabel: code,
                onTap: () =>
                    localeProvider.setLocale(Locale(code.toLowerCase())),
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: AppMotion.fast,
                    style: AppText.label(
                      size: 13,
                      weight: FontWeight.w700,
                      color: selected
                          ? AppColors.ink
                          : Colors.white.withValues(alpha: 0.8),
                    ),
                    child: Text(code),
                  ),
                ),
              ),
            );

        return Container(
          width: 96,
          height: 40,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: AppMotion.medium,
                curve: AppMotion.spring,
                alignment:
                    isEnglish ? Alignment.centerLeft : Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  option('EN', isEnglish),
                  option('FR', !isEnglish),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
