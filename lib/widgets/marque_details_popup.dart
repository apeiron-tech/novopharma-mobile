import 'package:flutter/material.dart';
import 'package:novopharma/models/marque.dart';
import 'package:novopharma/theme.dart';
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
            backgroundColor: LightModeColors.lightError,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 10,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header (Title + Close Icon)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Détails Marque',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: LightModeColors.dashboardTextPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2. Scrollable Body Content
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo & Name Section
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: widget.marque.logo != null && widget.marque.logo!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        widget.marque.logo!,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) =>
                                            _buildLogoFallback(),
                                      ),
                                    )
                                  : _buildLogoFallback(),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.marque.marqueName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: LightModeColors.dashboardTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Secteur Filter Section (Replaces Categories)
                      if (secteurs.isNotEmpty) ...[
                        Row(
                          children: [
                            const Text(
                              'Secteurs',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: LightModeColors.dashboardTextPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: LightModeColors.lightPrimary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${secteurs.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: LightModeColors.lightPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Horizontal scrollable chip list with "Tous" + available secteurs
                        SizedBox(
                          height: 38,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            children: [
                              // "Tous" Chip
                              _buildSecteurChip(
                                label: 'Tous',
                                isSelected: _selectedSecteur == null,
                                onTap: () {
                                  setState(() {
                                    _selectedSecteur = null;
                                  });
                                },
                              ),
                              const SizedBox(width: 6),
                              ...secteurs.map((secteur) {
                                final isSelected =
                                    _selectedSecteur?.toLowerCase() == secteur.toLowerCase();
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _buildSecteurChip(
                                    label: secteur,
                                    isSelected: isSelected,
                                    onTap: () {
                                      setState(() {
                                        _selectedSecteur = isSelected ? null : secteur;
                                      });
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      const Divider(height: 1),
                      const SizedBox(height: 14),

                      // Contact List Header
                      Row(
                        children: [
                          const Text(
                            'Contacts et Responsables',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: LightModeColors.dashboardTextPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${contacts.length}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Contacts List
                      if (contacts.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            _selectedSecteur != null
                                ? 'Aucun contact disponible pour le secteur "$_selectedSecteur".'
                                : 'Aucun contact disponible pour cette marque.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: contacts.length,
                          itemBuilder: (context, index) {
                            final contact = contacts[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 0,
                              color: Colors.grey.shade50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: LightModeColors.lightPrimary
                                          .withValues(alpha: 0.1),
                                      child: const Icon(
                                        Icons.person,
                                        size: 20,
                                        color: LightModeColors.lightPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            contact.responsibleName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: LightModeColors.dashboardTextPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            contact.phoneNumber,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          if (contact.secteur != null &&
                                              contact.secteur!.trim().isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.location_on_outlined,
                                                  size: 13,
                                                  color: LightModeColors.lightPrimary,
                                                ),
                                                const SizedBox(width: 3),
                                                Flexible(
                                                  child: Text(
                                                    contact.secteur!.trim(),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w500,
                                                      color: LightModeColors.lightPrimary,
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
                                    // Direct phone call button
                                    Material(
                                      color: Colors.green.shade50,
                                      shape: const CircleBorder(),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.phone,
                                          color: Colors.green,
                                          size: 20,
                                        ),
                                        onPressed: () => _makePhoneCall(
                                          context,
                                          contact.phoneNumber,
                                        ),
                                        tooltip: 'Appeler ${contact.responsibleName}',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. Fixed Bottom Action Button
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LightModeColors.lightPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                child: const Text(
                  'Fermer',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecteurChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? LightModeColors.lightPrimary
              : LightModeColors.lightPrimary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? LightModeColors.lightPrimary
                : LightModeColors.lightPrimary.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: LightModeColors.lightPrimary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : LightModeColors.lightPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildLogoFallback() {
    return Center(
      child: Text(
        widget.marque.marqueName.isNotEmpty
            ? widget.marque.marqueName.substring(0, 1).toUpperCase()
            : 'M',
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: LightModeColors.lightPrimary,
        ),
      ),
    );
  }
}
