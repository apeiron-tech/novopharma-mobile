import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/models/pharmacy.dart';
import 'package:novopharma/screens/login_screen.dart';
import 'package:novopharma/services/pharmacy_service.dart';
import 'package:novopharma/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:novopharma/utils/auth_error_handler.dart';
import 'package:novopharma/widgets/terms_conditions_modal.dart';
import 'package:dropdown_search/dropdown_search.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;
  bool _isButtonEnabled = false;

  DateTime? _selectedDate;
  Pharmacy? _selectedPharmacy;
  String? _selectedRole;
  String? _selectedCity;
  late Future<List<Pharmacy>> _pharmaciesFuture;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, String>> _positions = [
    {'value': 'Pharmacien titulaire', 'key': 'pharmacienTitulaire'},
    {'value': 'Pharmacien assistant', 'key': 'pharmacienAssistant'},
    {'value': 'Responsable para', 'key': 'responsablePara'},
    {'value': 'Préparateur', 'key': 'preparateurOfficine'},
  ];

  final List<String> _cities = [
    'Ariana',
    'Béja',
    'Ben Arous',
    'Bizerte',
    'El Kef',
    'Gabes',
    'Gafsa',
    'Jendouba',
    'Kairouan',
    'Kasserine',
    'Kebili',
    'Mahdia',
    'Manouba',
    'Medenine',
    'Monastir',
    'Nabeul',
    'Sfax',
    'Sidi Bouzid',
    'Siliana',
    'Sousse',
    'Tataouine',
    'Tozeur',
    'Tunis',
    'Zaghouan',
  ];

  @override
  void initState() {
    super.initState();
    _pharmaciesFuture = PharmacyService().getPharmacies();
    _firstNameController.addListener(_updateButtonState);
    _lastNameController.addListener(_updateButtonState);
    _emailController.addListener(_updateButtonState);
    _passwordController.addListener(_updateButtonState);
    _confirmPasswordController.addListener(_updateButtonState);
    _phoneController.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    _firstNameController.removeListener(_updateButtonState);
    _lastNameController.removeListener(_updateButtonState);
    _emailController.removeListener(_updateButtonState);
    _passwordController.removeListener(_updateButtonState);
    _confirmPasswordController.removeListener(_updateButtonState);
    _phoneController.removeListener(_updateButtonState);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _updateButtonState() {
    final bool isFormValid = _formKey.currentState?.validate() ?? false;
    final bool isPasswordMatching =
        _passwordController.text == _confirmPasswordController.text;
    final bool allFieldsFilled =
        _firstNameController.text.isNotEmpty &&
        _lastNameController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _phoneController.text.isNotEmpty &&
        _selectedDate != null &&
        _selectedPharmacy != null &&
        _selectedRole != null &&
        _selectedCity != null;

    final bool shouldBeEnabled =
        isFormValid && isPasswordMatching && allFieldsFilled && _agreeToTerms;

    if (shouldBeEnabled != _isButtonEnabled) {
      setState(() {
        _isButtonEnabled = shouldBeEnabled;
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      // Crop the image
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recadrer la photo',
            toolbarColor: AppColors.indigo,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppColors.indigo,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'Recadrer la photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _profileImage = File(croppedFile.path);
        });
        _updateButtonState();
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate ??
          DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
      _updateButtonState();
    }
  }

  Future<void> _handleSignUp() async {
    // The button state should prevent this from being called if invalid
    if (!_isButtonEnabled) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final tempUserId = DateTime.now().millisecondsSinceEpoch.toString();
    String? downloadUrl;
    if (_profileImage != null) {
      downloadUrl = await StorageService().uploadProfilePicture(
        tempUserId,
        _profileImage!,
      );
    }

    final error = await authProvider.signUp(
      name:
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
      email: _emailController.text.trim(),
      password: _passwordController.text,
      dateOfBirth: _selectedDate!,
      pharmacyId: _selectedPharmacy!.id,
      pharmacyName: _selectedPharmacy!.name,
      phone: _phoneController.text.trim(),
      avatarUrl: downloadUrl ?? '',
      role: _selectedRole!,
      position: '',
      city: _selectedCity,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        final errorMessage = AuthErrorHandler.getErrorMessage(context, error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.coralDeep,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        // Pop the screen to let the AuthWrapper handle redirection
        Navigator.of(context).pop();
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
              // Let the form scroll under the home indicator.
              bottom: false,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  22,
                  12,
                  22,
                  24 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    // One theme for the whole form: every field, checkbox
                    // and dropdown below reads it instead of styling itself.
                    child: GlassFormTheme(
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ..._buildHeader(l10n),
                            const SizedBox(height: 24),
                            Entrance(
                              delay: const Duration(milliseconds: 250),
                              offset: const Offset(0, 30),
                              child: _buildAvatarPicker(),
                            ),
                            const SizedBox(height: 16),
                            Entrance(
                              delay: const Duration(milliseconds: 320),
                              offset: const Offset(0, 40),
                              child: _buildInformationSection(l10n),
                            ),
                            const SizedBox(height: 16),
                            _buildSecuritySection(l10n),
                            const SizedBox(height: 16),
                            _buildTermsAndSubmit(l10n),
                            const SizedBox(height: 12),
                            _buildSignInLink(l10n),
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

  /// Back and brand, then the headline the screen opens on.
  List<Widget> _buildHeader(AppLocalizations l10n) {
    return [
      Entrance(
        offset: const Offset(0, -10),
        child: Row(
          children: [
            GlassIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onTap: () => Navigator.of(context).pop(),
            ),
            const Spacer(),
            const BrandLogo(height: 34),
          ],
        ),
      ),
      const SizedBox(height: 32),
      Entrance(
        delay: const Duration(milliseconds: 80),
        child: Text(
          l10n.createAccount,
          maxLines: 2,
          style: AppText.display(
            size: 38,
            weight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Entrance(
        delay: const Duration(milliseconds: 140),
        child: Text(
          l10n.joinCommunity,
          style: AppText.body(
            size: 15.5,
            color: Colors.white.withValues(alpha: 0.76),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Entrance(
        delay: const Duration(milliseconds: 190),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.allFieldsRequired,
                    style: AppText.label(size: 12.5, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildInformationSection(AppLocalizations l10n) {
    // Two fields share a row here, so they give up a little side padding.
    const narrowPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 17);

    return _buildModernCard(
      icon: Icons.person_outline_rounded,
      title: l10n.myInformation,
      children: [
        // Personal Information
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModernLabel(l10n.firstName),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _firstNameController,
                    style: GlassFormTheme.fieldText,
                    decoration: _buildModernInputDecoration(
                      hintText: l10n.firstNameHint,
                    ).copyWith(contentPadding: narrowPadding),
                    validator: (value) => (value?.isEmpty ?? true)
                        ? l10n.firstNameRequiredError
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModernLabel(l10n.lastName),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _lastNameController,
                    style: GlassFormTheme.fieldText,
                    decoration: _buildModernInputDecoration(
                      hintText: l10n.lastNameHint,
                    ).copyWith(contentPadding: narrowPadding),
                    validator: (value) => (value?.isEmpty ?? true)
                        ? l10n.lastNameRequiredError
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Contact Information
        _buildModernLabel(l10n.emailAddress),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          style: GlassFormTheme.fieldText,
          keyboardType: TextInputType.emailAddress,
          decoration: _buildModernInputDecoration(
            hintText: l10n.emailHint,
            prefixIcon: Icons.alternate_email_rounded,
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
        _buildModernLabel(l10n.phoneNumber),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phoneController,
          style: GlassFormTheme.fieldText,
          keyboardType: TextInputType.phone,
          decoration: _buildModernInputDecoration(
            hintText: l10n.phoneHint,
            prefixIcon: Icons.phone_outlined,
          ),
          validator: (value) =>
              (value?.isEmpty ?? true) ? l10n.phoneRequiredError : null,
        ),
        const SizedBox(height: 18),
        // Additional Details
        _buildModernLabel(l10n.dateOfBirth),
        const SizedBox(height: 8),
        TextFormField(
          controller: _dobController,
          style: GlassFormTheme.fieldText,
          readOnly: true,
          onTap: () => _selectDate(context),
          decoration: _buildModernInputDecoration(
            hintText: l10n.dateOfBirthHint,
            prefixIcon: Icons.calendar_today_outlined,
          ),
          validator: (value) =>
              (value?.isEmpty ?? true) ? l10n.dobRequiredError : null,
        ),
        // A hairline between the person and where they work.
        Divider(
          height: 45,
          thickness: 1,
          color: Colors.white.withValues(alpha: 0.14),
        ),
        _buildModernLabel(l10n.yourPharmacy),
        const SizedBox(height: 8),
        _buildPharmacyDropdown(),
        const SizedBox(height: 18),
        _buildModernLabel(l10n.yourPosition),
        const SizedBox(height: 8),
        _buildRoleDropdown(),
        const SizedBox(height: 18),
        _buildModernLabel(l10n.city),
        const SizedBox(height: 8),
        _buildCityDropdown(),
      ],
    );
  }

  Widget _buildSecuritySection(AppLocalizations l10n) {
    return _buildModernCard(
      icon: Icons.lock_outline_rounded,
      title: l10n.securityCardTitle,
      children: [
        _buildModernLabel(l10n.password),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          style: GlassFormTheme.fieldText,
          obscureText: _obscurePassword,
          decoration: _buildModernInputDecoration(
            hintText: l10n.passwordHint,
            prefixIcon: Icons.lock_outline_rounded,
          ).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () => setState(
                () => _obscurePassword = !_obscurePassword,
              ),
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
        const SizedBox(height: 18),
        _buildModernLabel(l10n.confirmPassword),
        const SizedBox(height: 8),
        TextFormField(
          controller: _confirmPasswordController,
          style: GlassFormTheme.fieldText,
          obscureText: _obscureConfirmPassword,
          decoration: _buildModernInputDecoration(
            hintText: l10n.confirmPasswordHint,
            prefixIcon: Icons.lock_outline_rounded,
          ).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
            ),
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return l10n.confirmPasswordRequiredError;
            }
            if (value != _passwordController.text) {
              return l10n.passwordMatchError;
            }
            return null;
          },
        ),
      ],
    );
  }

  /// The consent and the action it unlocks, in one pane.
  Widget _buildTermsAndSubmit(AppLocalizations l10n) {
    return Glass(
      style: GlassStyle.dark,
      blur: Glass.frost,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      padding: const EdgeInsets.fromLTRB(12, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Checkbox(
                value: _agreeToTerms,
                onChanged: (value) {
                  setState(() => _agreeToTerms = value ?? false);
                  _updateButtonState();
                },
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: AppText.body(
                      size: 13.5,
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
                    children: [
                      TextSpan(text: l10n.iAccept),
                      TextSpan(
                        text: l10n.termsAndPrivacy,
                        style: AppText.body(
                          size: 13.5,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ).copyWith(decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            TermsConditionsModal.show(context);
                          },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: PrimaryButton.mint(
              label: l10n.createAccount,
              icon: Icons.person_add_rounded,
              loading: _isLoading,
              onPressed: _isButtonEnabled ? _handleSignUp : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInLink(AppLocalizations l10n) {
    return Center(
      child: Pressable(
        onTap: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Text.rich(
            TextSpan(
              style: AppText.body(
                size: 15,
                color: Colors.white.withValues(alpha: 0.72),
              ),
              children: [
                TextSpan(text: l10n.alreadyHaveAccount),
                const TextSpan(text: ' '),
                TextSpan(
                  text: l10n.signIn,
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
    );
  }

  Widget _buildAvatarPicker() {
    final l10n = AppLocalizations.of(context)!;
    return SoftCard(
      style: GlassStyle.dark,
      blur: Glass.frost,
      radius: AppRadii.xl,
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
      onTap: _pickImage,
      child: Row(
        children: [
          SizedBox.square(
            dimension: 76,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.mintBright, AppColors.indigoBright],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: AppColors.inkSoft,
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : null,
                    child: _profileImage == null
                        ? Icon(
                            Icons.person_rounded,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 36,
                          )
                        : null,
                  ),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppGradients.mint,
                      border: Border.all(color: AppColors.ink, width: 2),
                    ),
                    child: const Icon(
                      Icons.photo_camera_rounded,
                      color: AppColors.ink,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              l10n.uploadProfilePicture,
              style: AppText.body(
                size: 15.5,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }

  Widget _buildModernLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: AppText.label(
          size: 13.5,
          color: Colors.white.withValues(alpha: 0.86),
        ),
      ),
    );
  }

  /// A titled pane of dark glass holding one group of fields.
  Widget _buildModernCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Glass(
      style: GlassStyle.dark,
      blur: Glass.frost,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(size: 21, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  /// Only what is specific to the field. Fill, borders, hint, icon and error
  /// colours come from the surrounding theme: [GlassFormTheme] on the page,
  /// the app theme inside the dropdown menus.
  InputDecoration _buildInputDecoration({
    required String hintText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
    );
  }

  InputDecoration _buildModernInputDecoration({
    required String hintText,
    IconData? prefixIcon,
  }) {
    return _buildInputDecoration(hintText: hintText, prefixIcon: prefixIcon);
  }

  /// The dropdown menus open on a light surface, but they capture the
  /// dark-glass form theme from the field that opened them. Hand them the
  /// page theme back so the search box and rows stay dark on light.
  Widget _lightPopup(BuildContext popupContext, Widget popupWidget) {
    return Theme(data: Theme.of(context), child: popupWidget);
  }

  static const _dropdownSuffix = DropdownSuffixProps(
    dropdownButtonProps: DropdownButtonProps(
      iconClosed: Icon(Icons.keyboard_arrow_down_rounded, size: 24),
      iconOpened: Icon(Icons.keyboard_arrow_up_rounded, size: 24),
    ),
  );

  /// For the lines that stand in for the pharmacy field when it cannot load.
  TextStyle get _fieldNoticeStyle => AppText.body(
        size: 14,
        weight: FontWeight.w600,
        color: AppColors.coralTint,
      );

  Widget _buildPharmacyDropdown() {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<Pharmacy>>(
      future: _pharmaciesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 58,
            child: Center(
              child: CapsuleLoader(
                size: 36,
                left: Colors.white,
                right: AppColors.mintBright,
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Text(
            l10n.pharmacyLoadError(snapshot.error.toString()),
            style: _fieldNoticeStyle,
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Text(l10n.noPharmaciesError, style: _fieldNoticeStyle);
        }

        final pharmacies = snapshot.data!;
        final filteredPharmacies = pharmacies
            .where((pharmacy) => pharmacy.clientCategory != 'Para-Pharmacie')
            .toList();
        return DropdownSearch<Pharmacy>(
          items: (filter, loadProps) => filteredPharmacies
              .where((p) =>
                  p.name.toLowerCase().contains(filter.toLowerCase()))
              .toList(),
          itemAsString: (Pharmacy pharmacy) => pharmacy.name,
          selectedItem: _selectedPharmacy,
          compareFn: (item, selectedItem) => item.id == selectedItem.id,
          suffixProps: _dropdownSuffix,
          decoratorProps: DropDownDecoratorProps(
            // The selected pharmacy, in white on the dark glass.
            baseStyle: GlassFormTheme.fieldText,
            decoration: _buildInputDecoration(
              hintText: l10n.selectYourPharmacy,
              prefixIcon: Icons.local_pharmacy_outlined,
            ),
          ),
          popupProps: PopupProps.menu(
            showSearchBox: true,
            containerBuilder: _lightPopup,
            searchFieldProps: TextFieldProps(
              decoration: _buildInputDecoration(
                hintText: l10n.search,
                prefixIcon: Icons.search_rounded,
              ),
            ),
            itemBuilder: (context, item, isSelected, isHighlighted) {
              return ListTile(
                title: Text(item.name),
                selected: isSelected,
              );
            },
          ),
          onChanged: (Pharmacy? newValue) {
            setState(() {
              _selectedPharmacy = newValue;
            });
            _updateButtonState();
          },
          validator: (value) =>
              value == null ? l10n.pleaseSelectPharmacy : null,
        );
      },
    );
  }

  Widget _buildRoleDropdown() {
    final l10n = AppLocalizations.of(context)!;
    final items = _positions.map((position) {
      String labelText;
      switch (position['key']) {
        case 'pharmacienTitulaire':
          labelText = l10n.pharmacienTitulaire;
          break;
        case 'pharmacienAssistant':
          labelText = l10n.pharmacienAssistant;
          break;
        case 'responsablePara':
          labelText = l10n.responsableParapharmacie;
          break;
        case 'preparateurOfficine':
          labelText = l10n.preparateurOfficine;
          break;
        default:
          labelText = position['key']!;
      }

      return DropdownMenuItem<String>(
        value: position['value'],
        child: Text(labelText, overflow: TextOverflow.ellipsis, maxLines: 1),
      );
    }).toList();

    return DropdownButtonFormField<String>(
      initialValue: _selectedRole,
      isExpanded: true,
      // `style` is what the open menu uses, and the menu is light. The
      // closed field draws its own white copy of the chosen row and hint.
      style: AppText.body(
        size: 16,
        weight: FontWeight.w500,
        color: AppColors.text,
      ),
      dropdownColor: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      iconEnabledColor: Colors.white.withValues(alpha: 0.7),
      hint: Text(
        l10n.selectPosition,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.body(
          size: 15,
          color: Colors.white.withValues(alpha: 0.42),
        ),
      ),
      selectedItemBuilder: (context) => [
        for (final item in items)
          DefaultTextStyle.merge(
            style: GlassFormTheme.fieldText,
            child: item.child,
          ),
      ],
      decoration: _buildInputDecoration(
        hintText: l10n.selectPosition,
        prefixIcon: Icons.work_outline_rounded,
      ),
      items: items,
      onChanged: (String? newValue) {
        setState(() {
          _selectedRole = newValue;
        });
        _updateButtonState();
      },
      validator: (value) => value == null ? l10n.pleaseSelectPosition : null,
    );
  }

  Widget _buildCityDropdown() {
    final l10n = AppLocalizations.of(context)!;
    return DropdownSearch<String>(
      items: (filter, loadProps) => _cities
          .where((city) => city.toLowerCase().contains(filter.toLowerCase()))
          .toList(),
      selectedItem: _selectedCity,
      suffixProps: _dropdownSuffix,
      decoratorProps: DropDownDecoratorProps(
        baseStyle: GlassFormTheme.fieldText,
        decoration: _buildInputDecoration(
          hintText: l10n.selectYourCity,
          prefixIcon: Icons.location_city_rounded,
        ),
      ),
      popupProps: PopupProps.menu(
        showSearchBox: true,
        containerBuilder: _lightPopup,
        searchFieldProps: TextFieldProps(
          decoration: _buildInputDecoration(
            hintText: l10n.search,
            prefixIcon: Icons.search_rounded,
          ),
        ),
      ),
      onChanged: (String? newValue) {
        setState(() {
          _selectedCity = newValue;
        });
        _updateButtonState();
      },
      validator: (value) => value == null ? l10n.cityRequiredError : null,
    );
  }
}
