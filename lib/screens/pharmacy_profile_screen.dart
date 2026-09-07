import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:novopharma/models/pharmacy.dart';
import 'package:novopharma/services/pharmacy_service.dart';
import 'package:novopharma/theme.dart';
import 'package:novopharma/screens/stock_brand_selection_screen.dart';
import 'package:novopharma/screens/stock_review_screen.dart';
import 'package:novopharma/widgets/bottom_navigation_bar.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/controllers/auth_provider.dart';

class PharmacyProfileScreen extends StatefulWidget {
  final String pharmacyId;
  final String pharmacyName;

  const PharmacyProfileScreen({
    super.key,
    required this.pharmacyId,
    required this.pharmacyName,
  });

  @override
  State<PharmacyProfileScreen> createState() => _PharmacyProfileScreenState();
}

class _PharmacyProfileScreenState extends State<PharmacyProfileScreen> {
  final PharmacyService _pharmacyService = PharmacyService();
  Pharmacy? _pharmacy;
  bool _isLoading = true;
  bool _isCheckingOut = false;
  bool _isCheckingIn = false;
  bool _isActiveSession = false;
  String? _activeVisitId;
  String? _globalActivePharmacyId;
  String? _globalActivePharmacyName;
  bool _locationPermissionGranted = false;
  bool _hasLocalDraft = false;
  String? _visitComment;
  String? _activePointOfSale;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _checkLocalDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftKey = 'stock_draft_${widget.pharmacyId}';
      final draftString = prefs.getString(draftKey);
      setState(() {
        _hasLocalDraft = (draftString != null);
      });
    } catch (e) {
      debugPrint("Error checking local draft: $e");
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        setState(() {
          _locationPermissionGranted = false;
          _isLoading = false;
        });
        return;
      }

      _locationPermissionGranted = true;
      _pharmacy = await _pharmacyService.getPharmacy(widget.pharmacyId);

      final prefs = await SharedPreferences.getInstance();
      _globalActivePharmacyId = prefs.getString('active_pharmacy_id');
      _globalActivePharmacyName = prefs.getString('active_pharmacy_name');
      _activeVisitId = prefs.getString('active_visit_id');

      _activePointOfSale = prefs.getString('active_point_of_sale');

      if (_globalActivePharmacyId == widget.pharmacyId &&
          _activeVisitId != null) {
        _isActiveSession = true;
        // Fetch comment and pointOfSale from Firestore
        final visitDoc = await FirebaseFirestore.instance
            .collection('visits_history')
            .doc(_activeVisitId)
            .get();
        if (visitDoc.exists) {
          _visitComment = visitDoc.data()?['commentaire'] as String?;
          final pos = visitDoc.data()?['pointOfSale'] as String?;
          if (pos != null) {
            _activePointOfSale = pos;
            await prefs.setString('active_point_of_sale', pos);
          }
        }
      } else {
        _isActiveSession = false;
        _visitComment = null;
        _activePointOfSale = null;
      }

      await _checkLocalDraft();
    } catch (e) {
      debugPrint("Error loading pharmacy details: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showGPSDisabledDialog() async {
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "GPS désactivé",
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: LightModeColors.lightErrorContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_off_rounded,
                      color: LightModeColors.lightError,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "GPS désactivé",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: LightModeColors.dashboardTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Votre GPS semble être désactivé. Veuillez l'activer dans les paramètres de votre téléphone pour utiliser cette fonctionnalité.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: LightModeColors.novoPharmaGray,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(
                              color: LightModeColors.novoPharmaBlue,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Annuler",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await Geolocator.openLocationSettings();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LightModeColors.novoPharmaBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Paramètres",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _checkLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _showGPSDisabledDialog();
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("Error checking location permission: $e");
      return false;
    }
  }

  Future<void> _handleCheckIn() async {
    final hasPermission = await _checkLocationPermission();
    if (!hasPermission) return;

    String? selectedPointOfSale;
    final hasPOS = (_pharmacy?.hasPointsOfSale ?? false) && (_pharmacy?.pointsOfSale.isNotEmpty ?? false);
    if (hasPOS) {
      selectedPointOfSale = _pharmacy!.pointsOfSale.first.name;
    }

    final confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Confirmation",
      pageBuilder: (context, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Align(
              alignment: Alignment.center,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(22),
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header icon badge
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: LightModeColors.novoPharmaLightBlue,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: LightModeColors.novoPharmaBlue.withValues(alpha: 0.15),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: LightModeColors.novoPharmaBlue,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "Confirmer le Check-in",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: LightModeColors.dashboardTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Pharmacy card info
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: LightModeColors.novoPharmaLightGray,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: LightModeColors.lightOutlineVariant),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: LightModeColors.novoPharmaLightBlue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.local_pharmacy_rounded,
                                size: 16,
                                color: LightModeColors.novoPharmaBlue,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Pharmacie cible",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: LightModeColors.novoPharmaGray,
                                    ),
                                  ),
                                  Text(
                                    widget.pharmacyName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: LightModeColors.dashboardTextPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasPOS) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(
                              Icons.store_rounded,
                              size: 15,
                              color: LightModeColors.novoPharmaBlue,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              "Sélectionner le point de vente",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: LightModeColors.dashboardTextPrimary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: LightModeColors.novoPharmaLightBlue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "${_pharmacy!.pointsOfSale.length}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: LightModeColors.novoPharmaBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _pharmacy!.pointsOfSale.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final pos = _pharmacy!.pointsOfSale[idx];
                              final isSelected = selectedPointOfSale == pos.name;
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      selectedPointOfSale = pos.name;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? LightModeColors.novoPharmaLightBlue.withValues(alpha: 0.55)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? LightModeColors.novoPharmaBlue
                                            : LightModeColors.lightOutlineVariant,
                                        width: isSelected ? 1.6 : 1.0,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: LightModeColors.novoPharmaBlue.withValues(alpha: 0.1),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(7),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? LightModeColors.novoPharmaBlue
                                                : LightModeColors.novoPharmaLightGray,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.storefront_rounded,
                                            size: 15,
                                            color: isSelected ? Colors.white : LightModeColors.novoPharmaGray,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                pos.name,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                                  color: isSelected
                                                      ? LightModeColors.novoPharmaDarkBlue
                                                      : LightModeColors.dashboardTextPrimary,
                                                ),
                                              ),
                                              if (pos.city.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.place_outlined,
                                                      size: 11,
                                                      color: isSelected
                                                          ? LightModeColors.novoPharmaBlue
                                                          : LightModeColors.novoPharmaGray,
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      pos.city,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: isSelected
                                                            ? LightModeColors.novoPharmaBlue
                                                            : LightModeColors.novoPharmaGray,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle_rounded
                                              : Icons.radio_button_unchecked_rounded,
                                          size: 20,
                                          color: isSelected
                                              ? LightModeColors.novoPharmaBlue
                                              : LightModeColors.novoPharmaGray.withValues(alpha: 0.4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        const Text(
                          "Voulez-vous enregistrer votre Check-in pour cette pharmacie ?",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: LightModeColors.novoPharmaGray,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                side: const BorderSide(color: LightModeColors.lightOutlineVariant, width: 1.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "Annuler",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: LightModeColors.novoPharmaGray,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: LightModeColors.novoPharmaBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_rounded, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    "Confirmer",
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isCheckingIn = true);

    try {
      GeoPoint checkInGeoPoint = const GeoPoint(0, 0);
      try {
        if (_locationPermissionGranted) {
          Position pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          checkInGeoPoint = GeoPoint(pos.latitude, pos.longitude);
        }
      } catch (e) {
        debugPrint("Error fetching exact check-in location: $e");
      }

      final docRef = FirebaseFirestore.instance
          .collection('visits_history')
          .doc();
      final visitId = docRef.id;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.userProfile;

      final checkInData = {
        'visitId': visitId,
        'dermoId': user?.uid ?? '',
        'pharmacyId': widget.pharmacyId,
        'pharmacyName': widget.pharmacyName,
        'checkInLocation': checkInGeoPoint,
        'checkInTime': FieldValue.serverTimestamp(),
        'checkOutTime': null,
        'status': 'active',
        if (selectedPointOfSale != null) 'pointOfSale': selectedPointOfSale,
      };

      await docRef.set(checkInData);

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_visit_id', visitId);
      await prefs.setString('active_pharmacy_id', widget.pharmacyId);
      await prefs.setString('active_pharmacy_name', widget.pharmacyName);
      if (selectedPointOfSale != null) {
        await prefs.setString('active_point_of_sale', selectedPointOfSale!);
      } else {
        await prefs.remove('active_point_of_sale');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Check-in effectué avec succès")),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erreur lors du Check-in: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingIn = false);
      }
    }
  }

  Future<void> _showCommentDialog() async {
    final textController = TextEditingController(text: _visitComment ?? '');
    final confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Commentaire",
      pageBuilder: (context, anim1, anim2) {
        final double screenWidth = MediaQuery.of(context).size.width;
        final double scale = (screenWidth > 600) ? 1.4 : 1.0;
        return Align(
          alignment: Alignment.center,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 24 * scale),
            padding: EdgeInsets.all(24 * scale),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10 * scale),
                        decoration: const BoxDecoration(
                          color: LightModeColors.novoPharmaLightBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: LightModeColors.novoPharmaBlue,
                          size: 24 * scale,
                        ),
                      ),
                      SizedBox(width: 14 * scale),
                      Text(
                        "Ajouter un commentaire",
                        style: TextStyle(
                          fontSize: 18 * scale,
                          fontWeight: FontWeight.bold,
                          color: LightModeColors.dashboardTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20 * scale),
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Saisissez votre commentaire ici...",
                      hintStyle: TextStyle(fontSize: 14 * scale, color: LightModeColors.novoPharmaGray),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: LightModeColors.lightOutlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: LightModeColors.lightOutlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: LightModeColors.novoPharmaBlue, width: 2),
                      ),
                    ),
                    style: TextStyle(fontSize: 14 * scale),
                  ),
                  SizedBox(height: 24 * scale),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14 * scale),
                            side: const BorderSide(
                              color: LightModeColors.novoPharmaBlue,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "Annuler",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * scale),
                          ),
                        ),
                      ),
                      SizedBox(width: 16 * scale),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LightModeColors.novoPharmaBlue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14 * scale),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "Enregistrer",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * scale),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirm == true) {
      final commentText = textController.text.trim();
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance
            .collection('visits_history')
            .doc(_activeVisitId)
            .update({'commentaire': commentText.isEmpty ? null : commentText});

        setState(() {
          _visitComment = commentText.isEmpty ? null : commentText;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Commentaire enregistré avec succès")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur lors de l'enregistrement: $e")),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleCheckOut() async {
    if (_activeVisitId == null) return;

    final confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Confirmation",
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: LightModeColors.lightErrorContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: LightModeColors.lightError,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Confirmer le Check-out",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: LightModeColors.dashboardTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Voulez-vous vraiment enregistrer votre Check-out et terminer votre visite ?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: LightModeColors.novoPharmaGray,
                    ),
                  ),
                  if (_visitComment == null || _visitComment!.trim().isEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context, false);
                          _showCommentDialog();
                        },
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: LightModeColors.novoPharmaBlue, size: 18),
                        label: const Text(
                          "Ajouter un commentaire",
                          style: TextStyle(
                            color: LightModeColors.novoPharmaBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: LightModeColors.novoPharmaBlue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(
                              color: LightModeColors.novoPharmaGray,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Annuler",
                            style: TextStyle(
                              color: LightModeColors.novoPharmaGray,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LightModeColors.lightError,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Déconnexion",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isCheckingOut = true);

    try {
      GeoPoint checkOutGeoPoint = const GeoPoint(0, 0);
      try {
        if (_locationPermissionGranted) {
          Position pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          checkOutGeoPoint = GeoPoint(pos.latitude, pos.longitude);
        }
      } catch (e) {
        debugPrint("Error fetching exact check-out location: $e");
      }

      // Update Firestore record
      await FirebaseFirestore.instance
          .collection('visits_history')
          .doc(_activeVisitId)
          .update({
            'checkOutTime': FieldValue.serverTimestamp(),
            'checkOutLocation': checkOutGeoPoint,
            'status': 'completed',
          });

      // Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_visit_id');
      await prefs.remove('active_pharmacy_id');
      await prefs.remove('active_pharmacy_name');
      await prefs.remove('active_point_of_sale');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Check-out effectué avec succès")),
        );
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/dashboard_home', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erreur lors du Check-out: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pharmacyName = _pharmacy?.name ?? widget.pharmacyName;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userProfile;

    final double screenWidth = MediaQuery.of(context).size.width;
    final double scaleFactor = (screenWidth > 600) ? 1.4 : 1.0;

    return BottomNavigationScaffoldWrapper(
      currentIndex: 0,
      onTap: (index) {},
      child: Scaffold(
        backgroundColor: LightModeColors.novoPharmaLightGray,
        appBar: AppBar(
          title: const Text(
            "Profil de la Pharmacie",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: LightModeColors.dashboardTextPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 16),
            onPressed: () {
              if (_isActiveSession) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/dashboard_home', (route) => false);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            if (_isActiveSession)
              IconButton(
                icon: _isCheckingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: LightModeColors.lightError,
                        ),
                      )
                    : const Icon(
                        Icons.logout_rounded,
                        color: LightModeColors.lightError,
                      ),
                tooltip: "Check-out",
                onPressed: _isCheckingOut ? null : _handleCheckOut,
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _locationPermissionGranted == false
            ? _buildGPSBlocker()
            : SingleChildScrollView(
                    padding: EdgeInsets.all(20.0 * scaleFactor),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Premium Banner Card
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(24 * scaleFactor),
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
                                color: LightModeColors.novoPharmaBlue
                                    .withOpacity(0.2),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.all(10 * scaleFactor),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.local_hospital_rounded,
                                  color: Colors.white,
                                  size: 28 * scaleFactor,
                                ),
                              ),
                              SizedBox(height: 16 * scaleFactor),
                              Text(
                                pharmacyName,
                                style: TextStyle(
                                  fontSize: 20 * scaleFactor,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (_pharmacy != null &&
                                  _pharmacy!.clientCategory.isNotEmpty) ...[
                                SizedBox(height: 8 * scaleFactor),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10 * scaleFactor,
                                    vertical: 4 * scaleFactor,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _pharmacy!.clientCategory,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12 * scaleFactor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              if (_activePointOfSale != null && _activePointOfSale!.isNotEmpty) ...[
                                SizedBox(height: 8 * scaleFactor),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10 * scaleFactor,
                                    vertical: 4 * scaleFactor,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.storefront_rounded, color: Colors.white, size: 14 * scaleFactor),
                                      SizedBox(width: 6 * scaleFactor),
                                      Text(
                                        _activePointOfSale!,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12 * scaleFactor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: 20 * scaleFactor),

                        // Info List Container Card
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(20 * scaleFactor),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: LightModeColors.lightOutlineVariant,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: LightModeColors.novoPharmaBlue,
                                    size: 18 * scaleFactor,
                                  ),
                                  SizedBox(width: 8 * scaleFactor),
                                  Text(
                                    "Informations Générales",
                                    style: TextStyle(
                                      fontSize: 15 * scaleFactor,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          LightModeColors.dashboardTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 20 * scaleFactor),
                              _buildDetailRow(
                                icon: Icons.pin_drop_outlined,
                                label: "Adresse",
                                value: _pharmacy?.address.isNotEmpty == true
                                    ? _pharmacy!.address
                                    : "Non spécifiée",
                                scaleFactor: scaleFactor,
                              ),
                              Divider(
                                height: 28 * scaleFactor,
                                color: LightModeColors.lightOutlineVariant,
                              ),
                              _buildDetailRow(
                                icon: Icons.map_outlined,
                                label: "Ville / Zone",
                                value: _pharmacy != null
                                    ? "${_pharmacy!.city} / ${_pharmacy!.zone}"
                                    : "Non spécifiée",
                                scaleFactor: scaleFactor,
                              ),
                              if (_pharmacy != null &&
                                  _pharmacy!.phone.isNotEmpty) ...[
                                Divider(
                                  height: 28 * scaleFactor,
                                  color: LightModeColors.lightOutlineVariant,
                                ),
                                _buildDetailRow(
                                  icon: Icons.phone_outlined,
                                  label: "Téléphone",
                                  value: _pharmacy!.phone,
                                  scaleFactor: scaleFactor,
                                ),
                              ],
                              if (_pharmacy != null &&
                                  _pharmacy!.email.isNotEmpty) ...[
                                Divider(
                                  height: 28 * scaleFactor,
                                  color: LightModeColors.lightOutlineVariant,
                                ),
                                _buildDetailRow(
                                  icon: Icons.email_outlined,
                                  label: "E-mail",
                                  value: _pharmacy!.email,
                                  scaleFactor: scaleFactor,
                                ),
                              ],
                            ],
                          ),
                        ),

                        SizedBox(height: 20 * scaleFactor),

                        // New Stock Count button (Audit Stock)
                        if (_isActiveSession) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 54 * scaleFactor,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StockBrandSelectionScreen(
                                      pharmacyId: widget.pharmacyId,
                                      pharmacyName: widget.pharmacyName,
                                    ),
                                  ),
                                );
                                _checkLocalDraft();
                              },
                              icon: Icon(
                                Icons.inventory_2_rounded,
                                color: Colors.white,
                                size: 20 * scaleFactor,
                              ),
                              label: Text(
                                "Audit Stock",
                                style: TextStyle(
                                  fontSize: 15 * scaleFactor,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: LightModeColors.novoPharmaBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          SizedBox(height: 16 * scaleFactor),
                        ],

                        // Vente Manuelle button
                        if (_isActiveSession &&
                            user?.role == 'Dermo-conseiller') ...[
                          SizedBox(
                            width: double.infinity,
                            height: 54 * scaleFactor,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, '/manual-sale');
                              },
                              icon: Icon(
                                Icons.shopping_cart_rounded,
                                color: Colors.white,
                                size: 20 * scaleFactor,
                              ),
                              label: Text(
                                "Vente Manuelle",
                                style: TextStyle(
                                  fontSize: 15 * scaleFactor,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: LightModeColors.warning,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          SizedBox(height: 16 * scaleFactor),
                        ],

                        // Review local stock count draft button
                        if (_isActiveSession && _hasLocalDraft) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 54 * scaleFactor,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final synced = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StockReviewScreen(
                                      pharmacyId: widget.pharmacyId,
                                      pharmacyName: widget.pharmacyName,
                                    ),
                                  ),
                                );
                                if (synced == true) {
                                  // If sync was successful, refresh UI
                                  _loadData();
                                } else {
                                  _checkLocalDraft();
                                }
                              },
                              icon: Icon(
                                Icons.rate_review_rounded,
                                color: LightModeColors.novoPharmaBlue,
                                size: 20 * scaleFactor,
                              ),
                              label: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      "Réviser les lots d'inventaire",
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15 * scaleFactor,
                                        fontWeight: FontWeight.bold,
                                        color: LightModeColors.novoPharmaBlue,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8 * scaleFactor),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8 * scaleFactor,
                                      vertical: 2 * scaleFactor,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          LightModeColors.novoPharmaLightBlue,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      "En attente",
                                      style: TextStyle(
                                        fontSize: 11 * scaleFactor,
                                        fontWeight: FontWeight.bold,
                                        color: LightModeColors.novoPharmaBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: LightModeColors.novoPharmaBlue,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16 * scaleFactor),
                        ],

                        // Ajouter/Modifier Commentaire button
                        if (_isActiveSession) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 54 * scaleFactor,
                            child: ElevatedButton.icon(
                              onPressed: _showCommentDialog,
                              icon: Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: Colors.white,
                                size: 20 * scaleFactor,
                              ),
                              label: Text(
                                _visitComment == null || _visitComment!.trim().isEmpty
                                    ? "Ajouter Commentaire"
                                    : "Modifier Commentaire",
                                style: TextStyle(
                                  fontSize: 15 * scaleFactor,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: LightModeColors.novoPharmaBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          SizedBox(height: 16 * scaleFactor),
                        ],

                        // Check-in button
                        if (!_isActiveSession &&
                            _globalActivePharmacyId == null &&
                            user?.role == 'Dermo-conseiller') ...[
                          SizedBox(
                            width: double.infinity,
                            height: 54 * scaleFactor,
                            child: ElevatedButton.icon(
                              onPressed: _isCheckingIn ? null : _handleCheckIn,
                              icon: _isCheckingIn
                                  ? SizedBox(
                                      width: 20 * scaleFactor,
                                      height: 20 * scaleFactor,
                                      child: const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      Icons.login_rounded,
                                      color: Colors.white,
                                      size: 20 * scaleFactor,
                                    ),
                              label: Text(
                                _isCheckingIn
                                    ? "Enregistrement Check-in..."
                                    : "Effectuer le Check-in",
                                style: TextStyle(
                                  fontSize: 15 * scaleFactor,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: LightModeColors.novoPharmaBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          SizedBox(height: 16 * scaleFactor),
                        ],

                        // Active check-in at another pharmacy warning banner
                        if (!_isActiveSession &&
                            _globalActivePharmacyId != null &&
                            user?.role == 'Dermo-conseiller') ...[
                          Container(
                            padding: EdgeInsets.all(16 * scaleFactor),
                            decoration: BoxDecoration(
                              color: LightModeColors.lightErrorContainer,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: LightModeColors.lightError.withOpacity(
                                  0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: LightModeColors.lightError,
                                  size: 24 * scaleFactor,
                                ),
                                SizedBox(width: 12 * scaleFactor),
                                Expanded(
                                  child: Text(
                                    "Vous êtes actuellement check-in à \"$_globalActivePharmacyName\". Veuillez d'abord y effectuer votre check-out pour pouvoir vous check-in ici.",
                                    style: TextStyle(
                                      fontSize: 13 * scaleFactor,
                                      color:
                                          LightModeColors.lightOnErrorContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16 * scaleFactor),
                        ],
                        SizedBox(height: 80 * scaleFactor),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    double scaleFactor = 1.0,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8 * scaleFactor),
          decoration: BoxDecoration(
            color: LightModeColors.novoPharmaLightGray,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: LightModeColors.novoPharmaBlue, size: 18 * scaleFactor),
        ),
        SizedBox(width: 14 * scaleFactor),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11 * scaleFactor,
                  color: LightModeColors.novoPharmaGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4 * scaleFactor),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14 * scaleFactor,
                  fontWeight: FontWeight.bold,
                  color: LightModeColors.dashboardTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGPSBlocker() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: LightModeColors.lightError.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off_rounded,
                color: LightModeColors.lightError,
                size: 56,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              "Localisation GPS Requise",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: LightModeColors.dashboardTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "L'accès à la position GPS de votre téléphone est requis pour afficher le profil de la pharmacie et effectuer le Check-out.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: LightModeColors.novoPharmaGray,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.settings, color: Colors.white, size: 18),
                label: const Text(
                  "Autoriser / Réessayer",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: LightModeColors.novoPharmaBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
