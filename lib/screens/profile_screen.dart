import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/design/design.dart';
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
    final bool? confirm = await showGlassDialog<bool>(
      context: context,
      child: Builder(
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: BlisterIcon(
                icon: Icons.delete_forever_rounded,
                tone: Tone.coral,
                size: 52,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.deleteAccountTitle,
              style: AppText.display(size: 22, color: AppColors.coralDeep),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.deleteAccountConfirmation,
              style: AppText.body(size: 15),
            ),
            const SizedBox(height: 22),
            PrimaryButton.coral(
              label: l10n.deleteAccountConfirm,
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: l10n.cancel,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
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
            return const Center(child: CapsuleLoader());
          }
          final media = MediaQuery.of(context);
          final maxWidth = media.size.width > 600 ? 640.0 : double.infinity;

          Widget centered(Widget child) => Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          );

          // The page scrolls under the glass dock.
          return SingleChildScrollView(
            padding: EdgeInsets.only(bottom: media.padding.bottom + 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ink hero: who this is.
                InkHero(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.page,
                    10,
                    AppSpace.page,
                    26,
                  ),
                  child: centered(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Entrance(
                          offset: const Offset(0, -12),
                          child: _buildAppBar(context, l10n),
                        ),
                        const SizedBox(height: 24),
                        _buildProfileHeader(user, l10n),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.page,
                    22,
                    AppSpace.page,
                    0,
                  ),
                  child: centered(_buildProfileInfo(user, l10n)),
                ),
              ],
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
        GlassIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onTap: () {
            Navigator.pop(context);
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            l10n.myPersonalDetails,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.display(size: 19, color: Colors.white, height: 1.12),
          ),
        ),
        const SizedBox(width: 12),
        Pressable(
          pressedScale: 0.94,
          onTap: () {
            localeProvider.toggleLocale();
          },
          child: Glass(
            style: GlassStyle.dark,
            shadow: false,
            height: 44,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.language_rounded,
                  size: 19,
                  color: Colors.white,
                ),
                const SizedBox(width: 7),
                Text(
                  currentLang == 'en' ? 'EN' : 'FR',
                  style: AppText.label(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(UserModel user, AppLocalizations l10n) {
    final role = user.role.trim();
    final pharmacy = (user.pharmacy ?? '').trim();
    final city = (user.city ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Entrance(
          delay: const Duration(milliseconds: 80),
          scaleFrom: 0.96,
          child: Row(
            children: [
              _buildAvatar(user, l10n),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(size: 28, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (role.isNotEmpty || pharmacy.isNotEmpty || city.isNotEmpty) ...[
          const SizedBox(height: 20),
          Entrance(
            delay: const Duration(milliseconds: 160),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (role.isNotEmpty)
                  _HeroPill(icon: Icons.badge_rounded, label: role),
                if (pharmacy.isNotEmpty)
                  _HeroPill(
                    icon: Icons.local_pharmacy_rounded,
                    label: pharmacy,
                  ),
                if (city.isNotEmpty)
                  _HeroPill(icon: Icons.place_rounded, label: city),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAvatar(UserModel user, AppLocalizations l10n) {
    const double size = 104;
    // A little larger than the avatar so the camera button, which rides
    // its rim, stays fully inside the tappable bounds.
    return SizedBox.square(
      dimension: size + 8,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: AppAvatar(
              name: user.name,
              imageUrl: user.avatarUrl,
              size: size,
            ),
          ),
          if (_isUploadingAvatar)
            Positioned(
              left: 0,
              top: 0,
              width: size,
              height: size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.ink.withValues(alpha: 0.64),
                ),
                child: const Center(
                  child: CapsuleLoader(
                    size: 38,
                    left: Colors.white,
                    right: AppColors.mint,
                  ),
                ),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Tooltip(
              message: l10n.uploadProfilePicture,
              child: Pressable(
                pressedScale: 0.9,
                semanticLabel: l10n.uploadProfilePicture,
                onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                child: SizedBox.square(
                  dimension: 48,
                  child: Center(
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: AppGradients.mint,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.ink, width: 2.5),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: AppColors.ink,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo(UserModel user, AppLocalizations l10n) {
    final formattedDob = user.dateOfBirth != null
        ? DateFormat('dd/MM/yyyy').format(user.dateOfBirth!)
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Personal Information Section
        Entrance(
          delay: const Duration(milliseconds: 220),
          child: SoftCard(
            padding: const EdgeInsets.fromLTRB(18, 20, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal Information',
                  style: AppText.display(size: 19),
                ),
                const SizedBox(height: 8),
                _buildInputPill(
                  icon: Icons.person_rounded,
                  label: l10n.fullName,
                  field: 'name',
                  controller: _nameController,
                  isEditing: _editingStates['name']!,
                ),
                _rowDivider,
                _buildInputPill(
                  icon: Icons.alternate_email_rounded,
                  label: l10n.email,
                  value: user.email,
                ),
                _rowDivider,
                _buildInputPill(
                  icon: Icons.phone_rounded,
                  label: l10n.phone,
                  field: 'phone',
                  controller: _phoneController,
                  isEditing: _editingStates['phone']!,
                ),
                _rowDivider,
                _buildInputPill(
                  icon: Icons.lock_rounded,
                  label: l10n.password,
                  value: '••••••••••••',
                  field: 'password',
                ),
                if (user.dateOfBirth != null) ...[
                  _rowDivider,
                  _buildInputPill(
                    icon: Icons.cake_rounded,
                    label: l10n.dateOfBirth,
                    value: formattedDob,
                  ),
                ],
                _rowDivider,
                _buildInputPill(
                  icon: Icons.local_pharmacy_rounded,
                  label: l10n.yourPharmacy,
                  value: user.pharmacy ?? 'N/A',
                ),
                if (user.pointOfSale != null &&
                    user.pointOfSale!.isNotEmpty) ...[
                  _rowDivider,
                  _buildInputPill(
                    icon: Icons.storefront_rounded,
                    label: l10n.pointOfSale,
                    value: user.pointOfSale,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Action Buttons
        Entrance(
          delay: const Duration(milliseconds: 280),
          child: SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BadgesScreen()),
              );
            },
            child: _buildActionRow(
              icon: Icons.shield_rounded,
              tone: Tone.amber,
              label: 'My Badges',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Entrance(
          delay: const Duration(milliseconds: 340),
          child: PrimaryButton(
            label: l10n.updateProfile,
            onPressed: _hasChanges ? _saveProfile : null,
            loading: _isLoading,
          ),
        ),
        const SizedBox(height: 24),
        // Leaving: sign out, then delete the account.
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            children: [
              Pressable(
                pressedScale: 0.98,
                onTap: _isLoading ? null : _signOut,
                child: _buildActionRow(
                  icon: Icons.logout_rounded,
                  tone: Tone.coral,
                  label: l10n.disconnect,
                  labelColor: AppColors.coralDeep,
                  trailing: _isLoading
                      ? const CapsuleLoader(
                          size: 26,
                          left: AppColors.coral,
                          right: AppColors.coralTint,
                        )
                      : null,
                ),
              ),
              _rowDivider,
              Pressable(
                pressedScale: 0.98,
                onTap: _isLoading ? null : _deleteAccount,
                child: _buildActionRow(
                  icon: Icons.delete_forever_rounded,
                  tone: Tone.coral,
                  label: l10n.deleteAccount,
                  labelColor: AppColors.coralDeep,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          onTap: () async {
            final Uri telLaunchUri = Uri(
              scheme: 'tel',
              path: '+216 98 667 540',
            );
            if (await canLaunchUrl(telLaunchUri)) {
              await launchUrl(telLaunchUri);
            }
          },
          child: _buildActionRow(
            icon: Icons.phone_in_talk_rounded,
            tone: Tone.mint,
            label: "Besoin d'aide ?",
            caption: 'Appeler le +216 98 667 540',
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget get _rowDivider => const Divider(height: 1, indent: 54);

  /// A settings row: tinted icon, label (with an optional caption under
  /// it) and a chevron, or [trailing] in its place.
  Widget _buildActionRow({
    required IconData icon,
    required String label,
    Tone tone = Tone.indigo,
    Color labelColor = AppColors.text,
    String? caption,
    Widget? trailing,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Row(
        children: [
          TintIcon(icon: icon, tone: tone, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppText.body(
                      size: 16,
                      weight: FontWeight.w600,
                      color: labelColor,
                      height: 1.25,
                    ),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: 3),
                    Text(caption, style: AppText.label(size: 13)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          trailing ??
              Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: tone == Tone.coral
                    ? AppColors.coral
                    : AppColors.textFaint,
              ),
        ],
      ),
    );
  }

  Widget _buildInputPill({
    required String label,
    required IconData icon,
    String? value,
    TextEditingController? controller,
    String? field,
    bool isEditing = false,
  }) {
    final bool isEditable = field != null;
    final bool isPassword = field == 'password';

    Widget? trailing;
    if (isEditing) {
      trailing = _buildRowButton(
        icon: Icons.check_rounded,
        filled: true,
        semanticLabel: MaterialLocalizations.of(context).okButtonLabel,
        onTap: () => _toggleEditMode(field!),
      );
    } else if (isEditable && !isPassword) {
      trailing = _buildRowButton(
        icon: Icons.edit_rounded,
        semanticLabel: label,
        onTap: () => _toggleEditMode(field),
      );
    } else if (isEditable && isPassword) {
      trailing = const SizedBox.square(
        dimension: 44,
        child: Icon(
          Icons.chevron_right_rounded,
          size: 24,
          color: AppColors.textFaint,
        ),
      );
    }

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Row(
        children: [
          TintIcon(icon: icon, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label(size: 12.5),
                  ),
                  const SizedBox(height: 3),
                  if (isEditing)
                    TextField(
                      controller: controller,
                      cursorColor: AppColors.indigo,
                      style: AppText.body(
                        size: 16,
                        weight: FontWeight.w600,
                        height: 1.25,
                      ),
                      decoration: InputDecoration(
                        filled: false,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        border: _fieldLine(AppColors.lineStrong),
                        enabledBorder: _fieldLine(AppColors.lineStrong),
                        focusedBorder: _fieldLine(AppColors.indigo, 1.8),
                        hintText: value ?? controller?.text ?? '',
                        hintStyle: AppText.body(
                          size: 16,
                          color: AppColors.textFaint,
                          height: 1.25,
                        ),
                      ),
                    )
                  else
                    Text(
                      value ?? controller?.text ?? '',
                      style: AppText.body(
                        size: 16,
                        weight: isEditable ? FontWeight.w600 : FontWeight.w500,
                        color: isEditable
                            ? AppColors.text
                            : AppColors.textMuted,
                        height: 1.25,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );

    if (isEditable && isPassword) {
      // The whole row opens the password screen, not just its chevron.
      return Pressable(
        pressedScale: 0.98,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ChangePasswordScreen(),
            ),
          );
        },
        child: row,
      );
    }
    return row;
  }

  UnderlineInputBorder _fieldLine(Color color, [double width = 1.2]) =>
      UnderlineInputBorder(
        borderSide: BorderSide(color: color, width: width),
      );

  /// The edit / confirm control at the end of an editable row.
  Widget _buildRowButton({
    required IconData icon,
    required String semanticLabel,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return Pressable(
      pressedScale: 0.9,
      semanticLabel: semanticLabel,
      onTap: onTap,
      child: SizedBox.square(
        dimension: 44,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? AppColors.indigo : AppColors.indigoTint,
            ),
            child: Icon(
              icon,
              size: 18,
              color: filled ? Colors.white : AppColors.indigoDeep,
            ),
          ),
        ),
      ),
    );
  }
}

/// A fact about the person, as a small pane of glass on the hero.
class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Glass(
      style: GlassStyle.dark,
      shadow: false,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.88)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label(size: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
