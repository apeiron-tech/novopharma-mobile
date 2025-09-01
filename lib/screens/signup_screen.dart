import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/models/pharmacy.dart';
import 'package:novopharma/screens/login_screen.dart';
import 'package:novopharma/services/pharmacy_service.dart';
import 'package:novopharma/theme.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

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

  DateTime? _selectedDate;
  Pharmacy? _selectedPharmacy;
  late Future<List<Pharmacy>> _pharmaciesFuture;

  @override
  void initState() {
    super.initState();
    _pharmaciesFuture = PharmacyService().getPharmacies();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _handleSignUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth')),
      );
      return;
    }
    if (_selectedPharmacy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your pharmacy')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final error = await authProvider.signUp(
      name: '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
      email: _emailController.text.trim(),
      password: _passwordController.text,
      dateOfBirth: _selectedDate!,
      pharmacyId: _selectedPharmacy!.id,
      pharmacyName: _selectedPharmacy!.name,
      phone: _phoneController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign up failed: $error')),
        );
      }
      // No navigation needed, AuthWrapper will handle it
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
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
              color: Colors.black87,
              size: 16,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  l10n.createAccount,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.joinCommunity,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: LightModeColors.novoPharmaGray,
                      ),
                ),
                const SizedBox(height: 40),
                // Name fields...
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.firstName,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _firstNameController,
                            decoration: _buildInputDecoration(hintText: 'John'),
                            validator: (value) => (value?.isEmpty ?? true) ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.lastName,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _lastNameController,
                            decoration: _buildInputDecoration(hintText: 'Doe'),
                            validator: (value) => (value?.isEmpty ?? true) ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Email field...
                _buildSectionHeader(l10n.emailAddress),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _buildInputDecoration(
                    hintText: 'john.doe@email.com',
                    prefixIcon: Icons.email_outlined,
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Email is required';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Phone Number
                _buildSectionHeader(l10n.phoneNumber),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _buildInputDecoration(
                    hintText: 'Enter your phone number',
                    prefixIcon: Icons.phone_outlined,
                  ),
                  validator: (value) => (value?.isEmpty ?? true) ? 'Phone number is required' : null,
                ),
                const SizedBox(height: 24),
                // Date of Birth
                _buildSectionHeader(l10n.dateOfBirth),
                TextFormField(
                  controller: _dobController,
                  readOnly: true,
                  onTap: () => _selectDate(context),
                  decoration: _buildInputDecoration(
                    hintText: 'Select your birthdate',
                    prefixIcon: Icons.calendar_today_outlined,
                  ),
                  validator: (value) => (value?.isEmpty ?? true) ? 'Date of birth is required' : null,
                ),
                const SizedBox(height: 24),
                // Pharmacy Dropdown
                _buildSectionHeader(l10n.yourPharmacy),
                _buildPharmacyDropdown(),
                const SizedBox(height: 24),
                // Password field...
                _buildSectionHeader(l10n.password),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _buildInputDecoration(
                    hintText: 'At least 8 characters',
                    prefixIcon: Icons.lock_outline,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: LightModeColors.novoPharmaGray),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Password is required';
                    if (value!.length < 8) return 'Password must be at least 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Confirm Password field...
                _buildSectionHeader(l10n.confirmPassword),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: _buildInputDecoration(
                    hintText: 'Re-enter your password',
                    prefixIcon: Icons.lock_outline,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: LightModeColors.novoPharmaGray),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Please confirm your password';
                    if (value != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                // Terms checkbox...
                Row(
                  children: [
                    Checkbox(
                      value: _agreeToTerms,
                      onChanged: (value) => setState(() => _agreeToTerms = value ?? false),
                      activeColor: LightModeColors.novoPharmaBlue,
                    ),
                    Expanded(
                      child: Text(l10n.agreeToTerms),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Create Account Button...
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _agreeToTerms && !_isLoading ? _handleSignUp : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LightModeColors.novoPharmaBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(l10n.createAccount, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 32),
                // Sign in link...
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.black87),
                        children: [
                          TextSpan(text: l10n.alreadyHaveAccount),
                          TextSpan(
                            text: l10n.signIn,
                            style: const TextStyle(
                              color: LightModeColors.novoPharmaBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  InputDecoration _buildInputDecoration({required String hintText, IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: LightModeColors.novoPharmaGray) : null,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: LightModeColors.novoPharmaBlue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
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
          return Text('Error loading pharmacies: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No pharmacies available.');
        }

        final pharmacies = snapshot.data!;
        return DropdownButtonFormField<Pharmacy>(
          value: _selectedPharmacy,
          decoration: _buildInputDecoration(
            hintText: l10n.selectYourPharmacy,
            prefixIcon: Icons.local_hospital_outlined,
          ),
          items: pharmacies.map((pharmacy) {
            return DropdownMenuItem<Pharmacy>(
              value: pharmacy,
              child: Text(pharmacy.name),
            );
          }).toList(),
          onChanged: (Pharmacy? newValue) {
            setState(() {
              _selectedPharmacy = newValue;
            });
          },
          validator: (value) => value == null ? l10n.pleaseSelectPharmacy : null,
        );
      },
    );
  }
}