import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/models/pharmacy.dart';
import 'package:novopharma/screens/login_screen.dart';
import 'package:novopharma/services/pharmacy_service.dart';
import 'package:novopharma/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:novopharma/utils/auth_error_handler.dart';
import 'package:novopharma/widgets/terms_conditions_modal.dart';
import 'package:novopharma/theme.dart';
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
            toolbarColor: LightModeColors.lightPrimary,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: LightModeColors.lightPrimary,
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
            backgroundColor: LightModeColors.lightError,
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

    return Scaffold(
      backgroundColor: LightModeColors.novoPharmaLightBlue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: LightModeColors.dashboardTextPrimary,
              size: 16,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Modern Header Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        LightModeColors.novoPharmaBlue,
                        LightModeColors.lightPrimary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: LightModeColors.novoPharmaBlue.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person_add_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.createAccount,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.joinCommunity,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.allFieldsRequired,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _buildAvatarPicker(),
                const SizedBox(height: 24),
                // Name fields in modern card
                _buildModernCard(
                  icon: Icons.person_outline,
                  title: l10n.myInformation,
                  children: [
                    // Personal Information
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildModernLabel(l10n.firstName),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _firstNameController,
                                decoration: _buildModernInputDecoration(
                                  hintText: l10n.firstNameHint,
                                ),
                                validator: (value) => (value?.isEmpty ?? true)
                                    ? l10n.firstNameRequiredError
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildModernLabel(l10n.lastName),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _lastNameController,
                                decoration: _buildModernInputDecoration(
                                  hintText: l10n.lastNameHint,
                                ),
                                validator: (value) => (value?.isEmpty ?? true)
                                    ? l10n.lastNameRequiredError
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Contact Information
                    _buildModernLabel(l10n.emailAddress),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _buildModernInputDecoration(
                        hintText: l10n.emailHint,
                        prefixIcon: Icons.email_outlined,
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true)
                          return l10n.emailRequiredError;
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!))
                          return l10n.emailValidError;
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildModernLabel(l10n.phoneNumber),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _buildModernInputDecoration(
                        hintText: l10n.phoneHint,
                        prefixIcon: Icons.phone_outlined,
                      ),
                      validator: (value) => (value?.isEmpty ?? true)
                          ? l10n.phoneRequiredError
                          : null,
                    ),
                    const SizedBox(height: 20),
                    // Additional Details
                    _buildModernLabel(l10n.dateOfBirth),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _dobController,
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      decoration: _buildModernInputDecoration(
                        hintText: l10n.dateOfBirthHint,
                        prefixIcon: Icons.calendar_today_outlined,
                      ),
                      validator: (value) => (value?.isEmpty ?? true)
                          ? l10n.dobRequiredError
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _buildModernLabel(l10n.yourPharmacy),
                    const SizedBox(height: 8),
                    _buildPharmacyDropdown(),
                    const SizedBox(height: 16),
                    _buildModernLabel(l10n.yourPosition),
                    const SizedBox(height: 8),
                    _buildRoleDropdown(),
                    const SizedBox(height: 16),
                    _buildModernLabel(l10n.city),
                    const SizedBox(height: 8),
                    _buildCityDropdown(),
                  ],
                ),
                const SizedBox(height: 20),
                // Security Card
                _buildModernCard(
                  icon: Icons.lock_outline,
                  title: l10n.securityCardTitle,
                  children: [
                    _buildModernLabel(l10n.password),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration:
                          _buildModernInputDecoration(
                            hintText: l10n.passwordHint,
                            prefixIcon: Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: const Color(0xFF9CA3AF),
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                      validator: (value) {
                        if (value?.isEmpty ?? true)
                          return l10n.passwordRequiredError;
                        if (value!.length < 8) return l10n.passwordLengthError;
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildModernLabel(l10n.confirmPassword),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration:
                          _buildModernInputDecoration(
                            hintText: l10n.confirmPasswordHint,
                            prefixIcon: Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: const Color(0xFF9CA3AF),
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              ),
                            ),
                          ),
                      validator: (value) {
                        if (value?.isEmpty ?? true)
                          return l10n.confirmPasswordRequiredError;
                        if (value != _passwordController.text)
                          return l10n.passwordMatchError;
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Terms checkbox...
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _agreeToTerms,
                        onChanged: (value) {
                          setState(() => _agreeToTerms = value ?? false);
                          _updateButtonState();
                        },
                        activeColor: LightModeColors.novoPharmaBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 13,
                              color: LightModeColors.novoPharmaGray,
                            ),
                            children: [
                              TextSpan(text: l10n.iAccept),
                              TextSpan(
                                text: l10n.termsAndPrivacy,
                                style: const TextStyle(
                                  color: LightModeColors.novoPharmaBlue,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w600,
                                ),
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
                ),
                const SizedBox(height: 32),
                // Create Account Button with modern design
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _isButtonEnabled
                        ? const LinearGradient(
                            colors: [
                              LightModeColors.novoPharmaBlue,
                              LightModeColors.lightPrimary,
                            ],
                          )
                        : null,
                    color: _isButtonEnabled ? null : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _isButtonEnabled
                        ? [
                            BoxShadow(
                              color: LightModeColors.novoPharmaBlue.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: ElevatedButton(
                    onPressed: _isButtonEnabled && !_isLoading
                        ? _handleSignUp
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isButtonEnabled && !_isLoading
                          ? null // Use the gradient defined in the container
                          : Colors.grey.shade300,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                              value: null,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_add_rounded, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                l10n.createAccount,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 32),
                // Sign in link with modern design
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: LightModeColors.novoPharmaGray,
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(text: l10n.alreadyHaveAccount),
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: l10n.signIn,
                              style: const TextStyle(
                                color: LightModeColors.novoPharmaBlue,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

  Widget _buildAvatarPicker() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: LightModeColors.novoPharmaLightBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  color: LightModeColors.novoPharmaBlue,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '${l10n.uploadProfilePicture}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: LightModeColors.novoPharmaBlue,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: LightModeColors.novoPharmaBlue.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 56,
                      backgroundColor: LightModeColors.novoPharmaLightBlue,
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : null,
                      child: _profileImage == null
                          ? Icon(
                              Icons.person_outline,
                              color: LightModeColors.novoPharmaGray,
                              size: 50,
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            LightModeColors.novoPharmaBlue,
                            LightModeColors.lightPrimary,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: LightModeColors.novoPharmaBlue.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernLabel(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: LightModeColors.novoPharmaGray,
      ),
    );
  }

  Widget _buildModernCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF1F9BD1), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF102132),
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

  InputDecoration _buildInputDecoration({
    required String hintText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade500),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: LightModeColors.novoPharmaBlue, size: 20)
          : null,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: LightModeColors.novoPharmaBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: LightModeColors.lightError),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: LightModeColors.lightError, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  InputDecoration _buildModernInputDecoration({
    required String hintText,
    IconData? prefixIcon,
  }) {
    return _buildInputDecoration(hintText: hintText, prefixIcon: prefixIcon);
  }

  Widget _buildPharmacyDropdown() {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<Pharmacy>>(
      future: _pharmaciesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text(l10n.pharmacyLoadError(snapshot.error.toString()));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Text(l10n.noPharmaciesError);
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
          decoratorProps: DropDownDecoratorProps(
            decoration: _buildInputDecoration(
              hintText: l10n.selectYourPharmacy,
              prefixIcon: Icons.local_hospital_outlined,
            ),
          ),
          popupProps: PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              decoration: _buildInputDecoration(
                hintText: l10n.search,
                prefixIcon: Icons.search,
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
    return DropdownButtonFormField<String>(
      initialValue: _selectedRole,
      isExpanded: true,
      decoration: _buildInputDecoration(
        hintText: l10n.selectPosition,
        prefixIcon: Icons.work_outline,
      ),
      items: _positions.map((position) {
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
      }).toList(),
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
      decoratorProps: DropDownDecoratorProps(
        decoration: _buildInputDecoration(
          hintText: l10n.selectYourCity,
          prefixIcon: Icons.location_city,
        ),
      ),
      popupProps: PopupProps.menu(
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          decoration: _buildInputDecoration(
            hintText: l10n.search,
            prefixIcon: Icons.search,
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
