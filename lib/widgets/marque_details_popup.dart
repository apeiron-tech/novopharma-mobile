import 'package:flutter/material.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/models/marque.dart';
import 'package:url_launcher/url_launcher_string.dart';

class MarqueDetailsPopup extends StatefulWidget {
  final MarqueModel marque;

  const MarqueDetailsPopup({
    super.key,
    required this.marque,
  });

  @override
  State<MarqueDetailsPopup> createState() => _MarqueDetailsPopupState();
}

class _MarqueDetailsPopupState extends State<MarqueDetailsPopup> {
  String? _selectedSecteur; // null means all / "Tous"

  List<String> get _availableSecteurs {
    final set = <String>{};
    for (final contact in widget.marque.contactList) {
      final s = contact.secteur?.trim();
      if (s != null && s.isNotEmpty) {
        set.add(s);
      }
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<MarqueContact> get _filteredContacts {
    if (_selectedSecteur == null || _selectedSecteur!.isEmpty) {
      return widget.marque.contactList;
    }
    return widget.marque.contactList
        .where((c) =>
            c.secteur != null &&
            c.secteur!.trim().toLowerCase() == _selectedSecteur!.trim().toLowerCase())
        .toList();
  }

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    final url = 'tel:$cleanPhone';
    try {
      final canLaunch = await canLaunchUrlString(url);
      if (canLaunch) {
        await launchUrlString(url);
      } else {
        await launchUrlString(url);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'appeler le numéro : $phoneNumber'),
            backgroundColor: AppColors.coralDeep,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    final secteurs = _availableSecteurs;
    final contacts = _filteredContacts;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      // Rises into place once. Transform only: the dialog route already fades
      // in, and a second fade here would switch the frost off while it runs.
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.medium,
        curve: AppMotion.emphasized,
        builder: (context, t, child) => Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
        ),
        child: Glass(
          blur: Glass.frost,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header (Logo, Title, Name + Close Icon)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.card,
                      ),
                      child: ClipOval(
                        child: widget.marque.logo != null &&
                                widget.marque.logo!.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(8),
                                child: Image.network(
                                  widget.marque.logo!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildLogoFallback(),
                                ),
                              )
                            : _buildLogoFallback(),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Détails marque',
                              style: AppText.label(size: 13, letterSpacing: 0),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.marque.marqueName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.display(size: 22),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CloseButton(onTap: () => Navigator.of(context).pop()),
                  ],
                ),
                const SizedBox(height: 18),

                // 2. Scrollable Body Content
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Secteur Filter Section (Dropdown)
                        if (secteurs.isNotEmpty) ...[
                          // A fixed-height row, so the "Tous" reset can come
                          // and go without nudging the dropdown below it.
                          SizedBox(
                            height: 44,
                            child: Row(
                              children: [
                                Text(
                                  'Secteur',
                                  style: AppText.display(size: 16),
                                ),
                                const SizedBox(width: 8),
                                _countPill('${secteurs.length}'),
                                if (_selectedSecteur != null) ...[
                                  const Spacer(),
                                  Pressable(
                                    onTap: () {
                                      setState(() {
                                        _selectedSecteur = null;
                                      });
                                    },
                                    child: SizedBox(
                                      height: 44,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.close_rounded,
                                              size: 15,
                                              color: AppColors.indigo,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Tous',
                                              style: AppText.label(
                                                size: 13.5,
                                                weight: FontWeight.w700,
                                                color: AppColors.indigo,
                                                letterSpacing: 0,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              border: Border.all(
                                color: _selectedSecteur != null
                                    ? AppColors.indigo.withValues(alpha: 0.5)
                                    : Colors.white,
                                width: _selectedSecteur != null ? 1.5 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: secteurs.contains(_selectedSecteur) ? _selectedSecteur : null,
                                isExpanded: true,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.indigo,
                                  size: 24,
                                ),
                                dropdownColor: AppColors.surface,
                                borderRadius: BorderRadius.circular(AppRadii.md),
                                elevation: 4,
                                menuMaxHeight: 250,
                                selectedItemBuilder: (context) {
                                  return [
                                    // Closed state for "Tous les secteurs"
                                    _buildClosedSecteur(
                                      icon: Icons.grid_view_rounded,
                                      label: 'Tous les secteurs',
                                      count: widget.marque.contactList.length,
                                    ),
                                    // Closed state for each sector
                                    ...secteurs.map((secteur) {
                                      final count = widget.marque.contactList
                                          .where((c) =>
                                              c.secteur != null &&
                                              c.secteur!.trim().toLowerCase() ==
                                                  secteur.trim().toLowerCase())
                                          .length;
                                      return _buildClosedSecteur(
                                        icon: Icons.location_on_rounded,
                                        label: secteur,
                                        count: count,
                                      );
                                    }),
                                  ];
                                },
                                items: [
                                  // Item "Tous les secteurs"
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: _buildSecteurMenuRow(
                                      icon: Icons.grid_view_rounded,
                                      label: 'Tous les secteurs',
                                      count: widget.marque.contactList.length,
                                      isSelected: _selectedSecteur == null,
                                    ),
                                  ),
                                  // Items for each secteur
                                  ...secteurs.map((secteur) {
                                    final isSelected = _selectedSecteur != null &&
                                        _selectedSecteur!.trim().toLowerCase() ==
                                            secteur.trim().toLowerCase();
                                    final count = widget.marque.contactList
                                        .where((c) =>
                                            c.secteur != null &&
                                            c.secteur!.trim().toLowerCase() ==
                                                secteur.trim().toLowerCase())
                                        .length;

                                    return DropdownMenuItem<String?>(
                                      value: secteur,
                                      child: _buildSecteurMenuRow(
                                        icon: Icons.location_on_outlined,
                                        label: secteur,
                                        count: count,
                                        isSelected: isSelected,
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (String? value) {
                                  setState(() {
                                    _selectedSecteur = value;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Contact List Header
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Contacts et responsables',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.display(size: 16),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _countPill('${contacts.length}'),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Contacts List
                        if (contacts.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              border: Border.all(color: Colors.white),
                            ),
                            child: Row(
                              children: [
                                const TintIcon(
                                  icon: Icons.person_off_rounded,
                                  size: 40,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedSecteur != null
                                        ? 'Aucun contact disponible pour le secteur "$_selectedSecteur".'
                                        : 'Aucun contact disponible pour cette marque.',
                                    style: AppText.body(
                                      size: 14,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: contacts.length,
                            itemBuilder: (context, index) {
                              final contact = contacts[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildContactRow(context, contact),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 3. Fixed Bottom Action Button
                SecondaryButton(
                  label: 'Fermer',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One person at the brand. The whole row places the call; the mint phone
  /// chip is where the eye (and the thumb) lands.
  Widget _buildContactRow(BuildContext context, MarqueContact contact) {
    final hasSecteur =
        contact.secteur != null && contact.secteur!.trim().isNotEmpty;

    return Tooltip(
      message: 'Appeler ${contact.responsibleName}',
      child: Pressable(
        // Direct phone call
        onTap: () => _makePhoneCall(context, contact.phoneNumber),
        semanticLabel: 'Appeler ${contact.responsibleName}',
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: Colors.white),
          ),
          child: Row(
            children: [
              const TintIcon(icon: Icons.person_rounded, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.responsibleName,
                      style: AppText.body(
                        size: 15,
                        weight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      contact.phoneNumber,
                      style: AppText.display(
                        size: 14.5,
                        weight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 0,
                      ),
                    ),
                    if (hasSecteur) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: AppColors.indigo,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              contact.secteur!.trim(),
                              style: AppText.label(
                                size: 12,
                                color: AppColors.indigoDeep,
                                letterSpacing: 0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const TintIcon(icon: Icons.call_rounded, tone: Tone.mint),
            ],
          ),
        ),
      ),
    );
  }

  /// A small count beside a heading or a sector.
  Widget _countPill(String text, {bool active = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? AppColors.indigoTint : AppColors.line,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        text,
        style: AppText.display(
          size: 12,
          color: active ? AppColors.indigoDeep : AppColors.textMuted,
          letterSpacing: 0,
        ),
      ),
    );
  }

  /// The dropdown's closed state: the sector in force and how many contacts
  /// it holds.
  Widget _buildClosedSecteur({
    required IconData icon,
    required String label,
    required int count,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.indigo),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppText.body(size: 14, weight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _countPill('$count'),
      ],
    );
  }

  /// One line of the open dropdown menu.
  Widget _buildSecteurMenuRow({
    required IconData icon,
    required String label,
    required int count,
    required bool isSelected,
  }) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.indigoTint : AppColors.surfaceSunken,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? AppColors.indigo : AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AppText.body(
              size: 14,
              weight: isSelected ? FontWeight.w700 : FontWeight.w400,
              color: isSelected ? AppColors.indigoDeep : AppColors.text,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _countPill('$count', active: isSelected),
        if (isSelected) ...[
          const SizedBox(width: 8),
          const Icon(
            Icons.check_rounded,
            size: 18,
            color: AppColors.indigo,
          ),
        ],
      ],
    );
  }

  Widget _buildLogoFallback() {
    return Center(
      child: Text(
        widget.marque.marqueName.isNotEmpty
            ? widget.marque.marqueName.substring(0, 1).toUpperCase()
            : 'M',
        style: AppText.display(
          size: 26,
          color: AppColors.indigo,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

/// The dialog's dismiss control: a round, quiet button with a full-size tap
/// target.
class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = MaterialLocalizations.of(context).closeButtonTooltip;
    return Tooltip(
      message: label,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.9,
        semanticLabel: label,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: 0.07),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close_rounded,
            size: 22,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}
