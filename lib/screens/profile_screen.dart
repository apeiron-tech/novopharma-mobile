import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/models/user_model.dart';
import 'package:novopharma/screens/auth_wrapper.dart';
import 'package:novopharma/widgets/bottom_navigation_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:novopharma/screens/change_password_screen.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/controllers/locale_provider.dart';
import 'package:novopharma/generated/l10n/app_localizations.dart';
import 'package:novopharma/screens/badges_screen.dart';
import 'package:novopharma/theme.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Map<String, bool> _editingStates = {'name': false, 'phone': false};

  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  bool _hasChanges = false;
  bool _isLoading = false;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).userProfile;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');

    _nameController.addListener(_checkForChanges);
    _phoneController.addListener(_checkForChanges);
  }

  void _checkForChanges() {
    final user = Provider.of<AuthProvider>(context, listen: false).userProfile;
    if (user == null) return;

    final bool changed =
        (_nameController.text != user.name) ||
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

  Future<void> _pickAndUploadAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      // Crop the image
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
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
        setState(() => _isUploadingAvatar = true);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final error = await authProvider.updateAvatar(File(croppedFile.path));

        if (mounted) {
          if (error == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Avatar mis à jour avec succès!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Échec de la mise à jour: $error')),
            );
          }
        }
        setState(() => _isUploadingAvatar = false);
      }
    }
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Update failed: $error')));
        }
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);

    // Wait for 1 second to provide feedback to the user
    await Future.delayed(const Duration(seconds: 1));

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signOut();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (route) => false,
      );
    }
  }

  Future<void> _deleteAccount() async {
    final l10n = AppLocalizations.of(context)!;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.deleteAccountTitle,
          style: const TextStyle(
            color: LightModeColors.lightError,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(l10n.deleteAccountConfirmation),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: LightModeColors.novoPharmaGray),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: LightModeColors.lightError,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(l10n.deleteAccountConfirm),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final error = await authProvider.deleteAccount();

      if (mounted) {
        if (error == null) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthWrapper()),
            (route) => false,
          );
        } else {
          setState(() => _isLoading = false);
          String errorMessage = error;
          if (error == 'requires-recent-login') {
            errorMessage = l10n.recentLoginRequiredError;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BottomNavigationScaffoldWrapper(
      currentIndex: 4,
      onTap: (index) {},
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final user = authProvider.userProfile;
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Container(
            color: LightModeColors.lightBackground,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    _buildAppBar(context, l10n),
                    const SizedBox(height: 24),
                    _buildProfileHeader(user),
                    const SizedBox(height: 24),
                    _buildProfileInfo(user, l10n),
                  ],
                ),
              ),
            ),
          );
        },
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
            Navigator.pop(context);
          },
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: const Icon(
              Icons.chevron_left,
              size: 24,
              color: LightModeColors.dashboardTextPrimary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            l10n.myPersonalDetails,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: LightModeColors.dashboardTextPrimary,
            ),
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
            foregroundColor: LightModeColors.dashboardTextPrimary,
            backgroundColor: LightModeColors.novoPharmaLightGray,
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
        Stack(
          children: [
            CircleAvatar(
              radius: 64,
              backgroundColor: LightModeColors.novoPharmaLightGray,
              backgroundImage: user.avatarUrl != null
                  ? NetworkImage(user.avatarUrl!)
                  : const NetworkImage(UserModel.defaultAvatarUrl),
              child: _isUploadingAvatar
                  ? Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        color: LightModeColors.lightSurface.withValues(
                          alpha: 0.6,
                        ),
                        borderRadius: BorderRadius.circular(64),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: LightModeColors.lightPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: LightModeColors.lightSurface,
                    width: 2,
                  ),
                ),
                child: GestureDetector(
                  onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                  child: Icon(
                    Icons.camera_alt,
                    color: LightModeColors.lightOnPrimary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          user.name,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: LightModeColors.dashboardTextPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: LightModeColors.dashboardTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfo(UserModel user, l10n) {
    final formattedDob = user.dateOfBirth != null
        ? DateFormat('dd/MM/yyyy').format(user.dateOfBirth!)
        : '';

    return Column(
      children: [
        // Personal Information Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: LightModeColors.lightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LightModeColors.lightOutline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: LightModeColors.dashboardTextPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildInputPill(
                label: l10n.fullName,
                field: 'name',
                controller: _nameController,
                isEditing: _editingStates['name']!,
              ),
              const SizedBox(height: 12),
              _buildInputPill(label: l10n.email, value: user.email),
              const SizedBox(height: 12),
              _buildInputPill(
                label: l10n.phone,
                field: 'phone',
                controller: _phoneController,
                isEditing: _editingStates['phone']!,
              ),
              const SizedBox(height: 12),
              _buildInputPill(
                label: l10n.password,
                value: '••••••••••••',
                field: 'password',
              ),
              if (user.dateOfBirth != null) ...[
                const SizedBox(height: 12),
                _buildInputPill(label: l10n.dateOfBirth, value: formattedDob),
              ],
              const SizedBox(height: 12),
              _buildInputPill(
                label: l10n.yourPharmacy,
                value: user.pharmacy ?? 'N/A',
              ),
              if (user.pointOfSale != null && user.pointOfSale!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildInputPill(
                  label: l10n.pointOfSale,
                  value: user.pointOfSale,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Action Buttons
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BadgesScreen()),
              );
            },
            icon: const Icon(Icons.shield_outlined),
            label: const Text('My Badges'),
            style: OutlinedButton.styleFrom(
              foregroundColor: LightModeColors.dashboardTextPrimary,
              side: BorderSide(color: LightModeColors.lightOutline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _hasChanges && !_isLoading ? _saveProfile : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: LightModeColors.lightPrimary,
              disabledBackgroundColor: LightModeColors.lightPrimary.withValues(
                alpha: 0.6,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(
                    color: LightModeColors.lightOnPrimary,
                  )
                : Text(
                    l10n.updateProfile,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: LightModeColors.lightOnPrimary,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _signOut,
            icon: _isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        LightModeColors.lightError,
                      ),
                    ),
                  )
                : Icon(
                    Icons.logout,
                    size: 18,
                    color: LightModeColors.lightError,
                  ),
            label: Text(
              l10n.disconnect,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: LightModeColors.lightError,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: LightModeColors.lightError,
              side: BorderSide(color: LightModeColors.lightError, width: 1),
              backgroundColor: LightModeColors.lightErrorContainer.withValues(
                alpha: 0.1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _isLoading ? null : _deleteAccount,
            icon: Icon(
              Icons.delete_forever_rounded,
              size: 20,
              color: LightModeColors.lightError.withValues(alpha: 0.8),
            ),
            label: Text(
              l10n.deleteAccount,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: LightModeColors.lightError.withValues(alpha: 0.8),
                decoration: TextDecoration.underline,
                decorationColor: LightModeColors.lightError.withValues(alpha: 0.8),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            final Uri telLaunchUri = Uri(
              scheme: 'tel',
              path: '+216 98 667 540',
            );
            if (await canLaunchUrl(telLaunchUri)) {
              await launchUrl(telLaunchUri);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Besoin d'aide ?",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: LightModeColors.dashboardTextPrimary,
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.phone_in_talk_rounded,
                      size: 26,
                      color: LightModeColors.dashboardTextPrimary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Appeler le +216 \n 98 667 540',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 8,
                        color: LightModeColors.dashboardTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isEditable
            ? LightModeColors.lightSurface
            : LightModeColors.novoPharmaLightGray,
        border: Border.all(color: LightModeColors.lightOutline),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (isEditable)
            BoxShadow(
              color: LightModeColors.dashboardTextPrimary.withValues(
                alpha: 0.05,
              ),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isEditing)
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: LightModeColors.dashboardTextTertiary,
              ),
            ),
          if (isEditing) const SizedBox(height: 4),
          if (isEditing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: TextStyle(
                        fontSize: 16,
                        color: LightModeColors.dashboardTextPrimary,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: value ?? controller?.text ?? '',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: LightModeColors.dashboardTextPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _toggleEditMode(field!),
                    child: Icon(
                      Icons.check,
                      size: 20,
                      color: LightModeColors.lightPrimary,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value ?? controller?.text ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        color: isEditable
                            ? LightModeColors.dashboardTextPrimary
                            : LightModeColors.dashboardTextSecondary,
                      ),
                    ),
                  ),
                  if (isEditable && !isPassword)
                    GestureDetector(
                      onTap: () => _toggleEditMode(field!),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 8),
                          Icon(
                            Icons.edit,
                            size: 20,
                            color: LightModeColors.dashboardTextTertiary,
                          ),
                        ],
                      ),
                    )
                  else if (isEditable && isPassword)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChangePasswordScreen(),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: LightModeColors.dashboardTextTertiary,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
