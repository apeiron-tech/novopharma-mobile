import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/controllers/fab_visibility_provider.dart';
import 'package:novopharma/models/user_model.dart';
import 'package:novopharma/widgets/bottom_navigation_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:novopharma/screens/change_password_screen.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/controllers/locale_provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Map<String, bool> _editingStates = {
    'name': false,
    'phone': false,
  };

  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  late FabVisibilityProvider _fabVisibilityProvider;

  bool _hasChanges = false;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Grab the provider instance here, where it's safe to do so.
    _fabVisibilityProvider = Provider.of<FabVisibilityProvider>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).userProfile;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');

    _nameController.addListener(_checkForChanges);
    _phoneController.addListener(_checkForChanges);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FabVisibilityProvider>(context, listen: false).hideFab();
    });
  }

  void _checkForChanges() {
    final user = Provider.of<AuthProvider>(context, listen: false).userProfile;
    if (user == null) return;

    final bool changed = (_nameController.text != user.name) ||
                         (_phoneController.text != (user.phone ?? ''));
    if (changed != _hasChanges) {
      setState(() {
        _hasChanges = changed;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _toggleEditMode(String field) {
    setState(() {
      _editingStates[field] = !_editingStates[field]!;
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final Map<String, dynamic> dataToUpdate = {};
    if (_nameController.text != authProvider.userProfile?.name) {
      dataToUpdate['name'] = _nameController.text;
    }
    if (_phoneController.text != (authProvider.userProfile?.phone ?? '')) {
      dataToUpdate['phone'] = _phoneController.text;
    }

    if (dataToUpdate.isNotEmpty) {
      final error = await authProvider.updateUserProfile(dataToUpdate);
      if (mounted) {
        if (error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
          setState(() {
            _editingStates['name'] = false;
            _editingStates['phone'] = false;
            _hasChanges = false;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Update failed: $error')),
          );
        }
      }
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _signOut() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return WillPopScope(
      onWillPop: () async {
        Provider.of<FabVisibilityProvider>(context, listen: false).showFab();
        return true;
      },
      child: BottomNavigationScaffoldWrapper(
        currentIndex: 4,
        onTap: (index) {},
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            final user = authProvider.userProfile;
            if (user == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return Container(
              color: const Color(0xFFFFFFFF),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _buildAppBar(context, l10n),
                      const SizedBox(height: 32),
                      _buildProfileHeader(user),
                      const SizedBox(height: 16),
                      _buildProfileInfo(user, l10n),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AppLocalizations l10n) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final currentLang = localeProvider.locale?.languageCode ?? 'en';

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            Provider.of<FabVisibilityProvider>(context, listen: false).showFab();
            Navigator.pop(context);
          },
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: const Icon(Icons.chevron_left, size: 24, color: Color(0xFF111827)),
          ),
        ),
        Expanded(
          child: Text(
            l10n.myPersonalDetails,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
          ),
        ),
        TextButton.icon(
          onPressed: () {
            localeProvider.toggleLocale();
          },
          icon: const Icon(Icons.language, size: 20),
          label: Text(
            currentLang == 'en' ? 'EN' : 'FR',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF111827),
            backgroundColor: const Color(0xFFF3F4F6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(UserModel user) {
    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundImage: user.avatarUrl != null
              ? NetworkImage(user.avatarUrl!)
              : const NetworkImage('https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face'),
        ),
        const SizedBox(height: 16),
        Text(user.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        const SizedBox(height: 4),
        Text(user.email, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF))),
      ],
    );
  }

  Widget _buildProfileInfo(UserModel user, AppLocalizations l10n) {
    final formattedDob = user.dateOfBirth != null ? DateFormat('dd/MM/yyyy').format(user.dateOfBirth!) : 'Not set';

    return Column(
      children: [
        const SizedBox(height: 32),
        _buildInputPill(
          label: l10n.fullName,
          field: 'name',
          controller: _nameController,
          isEditing: _editingStates['name']!,
        ),
        const SizedBox(height: 16),
        _buildInputPill(label: l10n.email, value: user.email),
        const SizedBox(height: 16),
        _buildInputPill(
          label: l10n.phone,
          field: 'phone',
          controller: _phoneController,
          isEditing: _editingStates['phone']!,
        ),
        const SizedBox(height: 16),
        _buildInputPill(label: l10n.password, value: '••••••••••••', field: 'password'),
        const SizedBox(height: 16),
        _buildInputPill(label: l10n.dateOfBirth, value: formattedDob),
        const SizedBox(height: 16),
        _buildInputPill(label: l10n.yourPharmacy, value: user.pharmacy ?? 'N/A'),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _hasChanges && !_isLoading ? _saveProfile : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E6EF7),
              disabledBackgroundColor: const Color(0xFF2E6EF7).withOpacity(0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(l10n.updateProfile, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _signOut,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Colors.red, width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(l10n.disconnect, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.red)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInputPill({
    required String label,
    String? value,
    TextEditingController? controller,
    String? field,
    bool isEditing = false,
  }) {
    final bool isEditable = field != null;
    final bool isPassword = field == 'password';

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isEditable ? const Color(0xFFFFFFFF) : const Color(0xFFF3F4F6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (isEditable)
            BoxShadow(
              color: const Color(0xFF111827).withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: isEditing
                ? TextField(
                    controller: controller,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      labelText: label,
                    ),
                  )
                : Text(
                    value ?? controller?.text ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: isEditable ? const Color(0xFF111827) : const Color(0xFF6B7280),
                    ),
                  ),
          ),
          if (isEditable)
            GestureDetector(
              onTap: () {
                if (isPassword) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                  );
                } else {
                  _toggleEditMode(field);
                }
              },
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: Icon(
                  isEditing ? Icons.check : (isPassword ? Icons.chevron_right : Icons.edit),
                  size: 20,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ),
        ],
      ),
    );
  }
}