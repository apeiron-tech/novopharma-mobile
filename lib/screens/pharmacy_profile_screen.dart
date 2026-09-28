import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:novopharma/models/pharmacy.dart';
import 'package:novopharma/services/pharmacy_service.dart';
import 'package:novopharma/navigation_observer.dart';
import 'package:novopharma/theme.dart';
import 'dart:io';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:novopharma/services/storage_service.dart';
import 'package:novopharma/screens/stock_brand_selection_screen.dart';
import 'package:novopharma/screens/stock_review_screen.dart';
import 'package:novopharma/widgets/bottom_navigation_bar.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

class _PharmacyProfileScreenState extends State<PharmacyProfileScreen>
    with RouteAware, WidgetsBindingObserver, TickerProviderStateMixin {
  final PharmacyService _pharmacyService = PharmacyService();
  Pharmacy? _pharmacy;
  bool _isLoading = true;
  bool _isDataLoading = false;
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
  final StorageService _storageService = StorageService();
  List<Map<String, dynamic>> _visitPhotos = [];
  bool _isUploadingPhoto = false;
  PageRoute? _subscribedRoute;

  late final AnimationController _arrowAnimController;
  late final Animation<double> _arrowAnimation;
  final ScrollController _photosScrollController = ScrollController();
  bool _canScrollRight = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _photosScrollController.addListener(_onPhotosScroll);

    _arrowAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _arrowAnimation = Tween<double>(begin: -2.0, end: 4.0).animate(
      CurvedAnimation(
        parent: _arrowAnimController,
        curve: Curves.easeInOut,
      ),
    );

    _loadData();
  }

  void _onPhotosScroll() {
    if (!_photosScrollController.hasClients) return;
    final maxScroll = _photosScrollController.position.maxScrollExtent;
    final currentScroll = _photosScrollController.offset;
    final canScroll = currentScroll < (maxScroll - 8) && maxScroll > 0;
    if (canScroll != _canScrollRight) {
      setState(() {
        _canScrollRight = canScroll;
      });
    }
  }

  void _checkScrollability() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _photosScrollController.hasClients) {
        final maxScroll = _photosScrollController.position.maxScrollExtent;
        final currentScroll = _photosScrollController.offset;
        final canScroll = currentScroll < (maxScroll - 8) && maxScroll > 0;
        if (canScroll != _canScrollRight) {
          setState(() {
            _canScrollRight = canScroll;
          });
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modalRoute = ModalRoute.of(context);
    if (modalRoute is PageRoute && modalRoute != _subscribedRoute) {
      if (_subscribedRoute != null) {
        routeObserver.unsubscribe(this);
      }
      _subscribedRoute = modalRoute;
      routeObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _photosScrollController.removeListener(_onPhotosScroll);
    _photosScrollController.dispose();
    _arrowAnimController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    // Automatically reloads visit data whenever returning to this screen
    _loadData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
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

  Future<void> _loadData({bool showLoading = false}) async {
    if (_isDataLoading) return;
    _isDataLoading = true;

    if (showLoading || _pharmacy == null) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      if (!_locationPermissionGranted) {
        final hasPermission = await _checkLocationPermission();
        if (!hasPermission) {
          if (mounted) {
            setState(() {
              _locationPermissionGranted = false;
              _isLoading = false;
            });
          }
          return;
        }
        _locationPermissionGranted = true;
      }

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
          final rawPhotos = visitDoc.data()?['photos'];
          if (rawPhotos is List) {
            _visitPhotos = rawPhotos
                .map((e) => Map<String, dynamic>.from(e as Map))
                .where((p) => p['isDeleted'] != true && p['deleted'] != true)
                .toList();
          } else {
            _visitPhotos = [];
          }
        }
      } else {
        _isActiveSession = false;
        _visitComment = null;
        _activePointOfSale = null;
        _visitPhotos = [];
      }

      await _checkLocalDraft();
    } catch (e) {
      debugPrint("Error loading pharmacy details: $e");
    } finally {
      _isDataLoading = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _checkScrollability();
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
                  color: Colors.black.withValues(alpha: 0.1),
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
                  color: Colors.black.withValues(alpha: 0.1),
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

  Future<void> _takeAndPreviewPhoto() async {
    if (_activeVisitId == null || !_isActiveSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucune session de visite active.")),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (pickedFile == null) return;

      final File file = File(pickedFile.path);
      if (!mounted) return;
      await _showPhotoPreviewModal(file);
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la capture : $e")),
        );
      }
    }
  }

  Future<void> _showPhotoPreviewModal(File imageFile) async {
    final result = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Aperçu de la photo",
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Aperçu de la photo",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: LightModeColors.dashboardTextPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx, 'cancel'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        imageFile,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(ctx, 'retake'),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text(
                            "Reprendre",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(
                              color: LightModeColors.novoPharmaBlue,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(ctx, 'confirm'),
                          icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                          label: const Text(
                            "Confirmer",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LightModeColors.novoPharmaBlue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
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

    if (result == 'confirm') {
      await _uploadVisitPhoto(imageFile);
    } else if (result == 'retake') {
      try {
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      } catch (_) {}
      _takeAndPreviewPhoto();
    } else {
      try {
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      } catch (_) {}
    }
  }

  Future<void> _uploadVisitPhoto(File imageFile) async {
    if (_activeVisitId == null || !_isActiveSession) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final uploadResult = await _storageService.uploadVisitPhoto(
        _activeVisitId!,
        imageFile,
      );

      if (uploadResult == null) {
        throw Exception("Échec de l'envoi de l'image.");
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.userProfile;
      final photoId = 'photo_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
      final nowTimestamp = Timestamp.now();

      final photoData = {
        'id': photoId,
        'url': uploadResult['url'],
        'storagePath': uploadResult['storagePath'],
        'takenAt': nowTimestamp,
        'uploadedAt': nowTimestamp,
        'source': 'mobile',
        'uploadedBy': user?.uid ?? 'Dermo-conseiller',
        'deleted': false,
        'isDeleted': false,
      };

      await FirebaseFirestore.instance
          .collection('visits_history')
          .doc(_activeVisitId)
          .update({
            'photos': FieldValue.arrayUnion([photoData]),
          });

      setState(() {
        _visitPhotos.add({
          'id': photoId,
          'url': uploadResult['url'],
          'storagePath': uploadResult['storagePath'],
          'takenAt': nowTimestamp,
          'uploadedAt': DateTime.now(),
          'source': 'mobile',
          'uploadedBy': user?.uid ?? 'Dermo-conseiller',
          'deleted': false,
          'isDeleted': false,
        });
      });
      _checkScrollability();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Photo enregistrée avec succès")),
        );
      }
    } catch (e) {
      debugPrint("Error uploading photo: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors du téléchargement : $e")),
        );
      }
    } finally {
      try {
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      } catch (_) {}

      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<bool> _confirmDeletePhoto(Map<String, dynamic> photo) async {
    if (!_isActiveSession || _activeVisitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La suppression n'est autorisée que lors d'une visite active."),
        ),
      );
      return false;
    }

    final confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Supprimer la photo",
      pageBuilder: (ctx, anim1, anim2) {
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
                  color: Colors.black.withValues(alpha: 0.1),
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
                      Icons.delete_forever_rounded,
                      color: LightModeColors.lightError,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Supprimer la photo ?",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: LightModeColors.dashboardTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Êtes-vous sûr de vouloir supprimer définitivement cette photo de la visite ?",
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
                          onPressed: () => Navigator.pop(ctx, false),
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
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LightModeColors.lightError,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Supprimer",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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

    if (confirm != true) return false;

    setState(() => _isLoading = true);

    try {
      if (photo['storagePath'] != null) {
        await _storageService.deleteVisitPhoto(photo['storagePath']);
      }

      final visitRef = FirebaseFirestore.instance
          .collection('visits_history')
          .doc(_activeVisitId);
      final visitSnap = await visitRef.get();
      if (visitSnap.exists) {
        final currentPhotos = List<Map<String, dynamic>>.from(
          (visitSnap.data()?['photos'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        final filtered = currentPhotos.where((p) => p['id'] != photo['id']).toList();
        await visitRef.update({'photos': filtered});
      }

      setState(() {
        _visitPhotos.removeWhere((p) => p['id'] == photo['id']);
      });
      _checkScrollability();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Photo supprimée avec succès")),
        );
      }
      return true;
    } catch (e) {
      debugPrint("Error deleting photo: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la suppression : $e")),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  void _viewPhotoPopup(int initialIndex) {
    if (_visitPhotos.isEmpty) return;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double scale = (screenWidth > 600) ? 1.3 : 1.0;

    int currentIndex = initialIndex.clamp(0, _visitPhotos.length - 1);
    final pageController = PageController(initialPage: currentIndex);

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Photo de la visite",
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, anim1, anim2) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final photo = (currentIndex < _visitPhotos.length) ? _visitPhotos[currentIndex] : null;
            DateTime? takenDate;
            if (photo != null && photo['takenAt'] != null) {
              if (photo['takenAt'] is Timestamp) {
                takenDate = (photo['takenAt'] as Timestamp).toDate();
              } else if (photo['takenAt'] is String) {
                takenDate = DateTime.tryParse(photo['takenAt'] as String);
              }
            }

            Future<void> handleDeletePhoto() async {
              final currentPhoto = (_visitPhotos.isNotEmpty && currentIndex < _visitPhotos.length)
                  ? _visitPhotos[currentIndex]
                  : null;
              if (currentPhoto == null) return;
              final deleted = await _confirmDeletePhoto(currentPhoto);
              if (deleted == true) {
                if (_visitPhotos.isEmpty) {
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                } else {
                  setDialogState(() {
                    if (currentIndex >= _visitPhotos.length) {
                      currentIndex = _visitPhotos.length - 1;
                    }
                    if (pageController.hasClients) {
                      pageController.jumpToPage(currentIndex);
                    }
                  });
                }
              }
            }

            return Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: 18 * scale,
                    vertical: 24 * scale,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: 520,
                    maxHeight: screenHeight * 0.82,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22 * scale),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22 * scale),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Popup Header
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16 * scale,
                            vertical: 14 * scale,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              bottom: BorderSide(
                                color: LightModeColors.lightOutlineVariant.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(7 * scale),
                                decoration: BoxDecoration(
                                  color: LightModeColors.novoPharmaLightBlue,
                                  borderRadius: BorderRadius.circular(10 * scale),
                                ),
                                child: Icon(
                                  Icons.photo_library_rounded,
                                  color: LightModeColors.novoPharmaBlue,
                                  size: 18 * scale,
                                ),
                              ),
                              SizedBox(width: 10 * scale),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Photo ${currentIndex + 1} sur ${_visitPhotos.length}",
                                      style: TextStyle(
                                        fontSize: 15 * scale,
                                        fontWeight: FontWeight.bold,
                                        color: LightModeColors.dashboardTextPrimary,
                                      ),
                                    ),
                                    if (takenDate != null)
                                      Text(
                                        "${takenDate.day.toString().padLeft(2, '0')}/${takenDate.month.toString().padLeft(2, '0')}/${takenDate.year} à ${takenDate.hour.toString().padLeft(2, '0')}:${takenDate.minute.toString().padLeft(2, '0')}",
                                        style: TextStyle(
                                          fontSize: 11 * scale,
                                          color: LightModeColors.novoPharmaGray,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Delete Button (when session is active)
                              if (_isActiveSession && photo != null) ...[
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: handleDeletePhoto,
                                    child: Container(
                                      padding: EdgeInsets.all(6 * scale),
                                      decoration: const BoxDecoration(
                                        color: LightModeColors.lightErrorContainer,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        color: LightModeColors.lightError,
                                        size: 18 * scale,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8 * scale),
                              ],
                              // Close Button
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => Navigator.pop(dialogCtx),
                                  child: Container(
                                    padding: EdgeInsets.all(6 * scale),
                                    decoration: const BoxDecoration(
                                      color: LightModeColors.novoPharmaLightGray,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: LightModeColors.dashboardTextSecondary,
                                      size: 18 * scale,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Image Area with PageView and Pinch-to-zoom
                        Flexible(
                          child: Container(
                            color: const Color(0xFF0F172A),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PageView.builder(
                                  controller: pageController,
                                  itemCount: _visitPhotos.length,
                                  onPageChanged: (newIdx) {
                                    setDialogState(() {
                                      currentIndex = newIdx;
                                    });
                                  },
                                  itemBuilder: (context, idx) {
                                    final currentUrl = _visitPhotos[idx]['url'] as String? ?? '';
                                    return InteractiveViewer(
                                      minScale: 1.0,
                                      maxScale: 4.0,
                                      child: Center(
                                        child: CachedNetworkImage(
                                          imageUrl: currentUrl,
                                          fit: BoxFit.contain,
                                          placeholder: (_, __) => const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          ),
                                          errorWidget: (_, __, ___) => Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.broken_image_rounded,
                                                color: Colors.white54,
                                                size: 48 * scale,
                                              ),
                                              SizedBox(height: 8 * scale),
                                              Text(
                                                "Image indisponible",
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12 * scale,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                // Previous Button
                                if (_visitPhotos.length > 1 && currentIndex > 0)
                                  Positioned(
                                    left: 10 * scale,
                                    child: GestureDetector(
                                      onTap: () {
                                        pageController.previousPage(
                                          duration: const Duration(milliseconds: 250),
                                          curve: Curves.easeInOut,
                                        );
                                      },
                                      child: Container(
                                        padding: EdgeInsets.all(8 * scale),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white24, width: 1),
                                        ),
                                        child: Icon(
                                          Icons.arrow_back_ios_new_rounded,
                                          color: Colors.white,
                                          size: 16 * scale,
                                        ),
                                      ),
                                    ),
                                  ),

                                // Next Button
                                if (_visitPhotos.length > 1 && currentIndex < _visitPhotos.length - 1)
                                  Positioned(
                                    right: 10 * scale,
                                    child: GestureDetector(
                                      onTap: () {
                                        pageController.nextPage(
                                          duration: const Duration(milliseconds: 250),
                                          curve: Curves.easeInOut,
                                        );
                                      },
                                      child: Container(
                                        padding: EdgeInsets.all(8 * scale),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white24, width: 1),
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: Colors.white,
                                          size: 16 * scale,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Popup Footer
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16 * scale,
                            vertical: 10 * scale,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(
                                color: LightModeColors.lightOutlineVariant.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.zoom_in_rounded,
                                    size: 15 * scale,
                                    color: LightModeColors.novoPharmaGray,
                                  ),
                                  SizedBox(width: 6 * scale),
                                  Text(
                                    "Pincez pour zoomer • Glissez",
                                    style: TextStyle(
                                      fontSize: 11 * scale,
                                      color: LightModeColors.novoPharmaGray,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (_isActiveSession && photo != null)
                                TextButton.icon(
                                  onPressed: handleDeletePhoto,
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: LightModeColors.lightError,
                                    size: 16 * scale,
                                  ),
                                  label: Text(
                                    "Supprimer",
                                    style: TextStyle(
                                      color: LightModeColors.lightError,
                                      fontSize: 12 * scale,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10 * scale,
                                      vertical: 4 * scale,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPhotosGallery(double scaleFactor) {
    final hasPhotos = _visitPhotos.isNotEmpty;
    final totalItems = _visitPhotos.length + (_isActiveSession ? 1 : 0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16 * scaleFactor),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: LightModeColors.novoPharmaBlue.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: LightModeColors.novoPharmaBlue.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.photo_library_rounded,
                    color: LightModeColors.novoPharmaBlue,
                    size: 20 * scaleFactor,
                  ),
                  SizedBox(width: 8 * scaleFactor),
                  Text(
                    "Photos de la visite (${_visitPhotos.length})",
                    style: TextStyle(
                      fontSize: 15 * scaleFactor,
                      fontWeight: FontWeight.bold,
                      color: LightModeColors.dashboardTextPrimary,
                    ),
                  ),
                  if (totalItems >= 4) ...[
                    SizedBox(width: 6 * scaleFactor),
                    AnimatedBuilder(
                      animation: _arrowAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_arrowAnimation.value * 0.7 * scaleFactor, 0),
                          child: child,
                        );
                      },
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 16 * scaleFactor,
                        color: LightModeColors.novoPharmaBlue,
                      ),
                    ),
                  ],
                ],
              ),
              if (_isActiveSession)
                TextButton.icon(
                  onPressed: _isUploadingPhoto ? null : _takeAndPreviewPhoto,
                  icon: _isUploadingPhoto
                      ? SizedBox(
                          width: 14 * scaleFactor,
                          height: 14 * scaleFactor,
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.add_a_photo_rounded,
                          size: 16 * scaleFactor,
                          color: LightModeColors.novoPharmaBlue,
                        ),
                  label: Text(
                    "Prendre",
                    style: TextStyle(
                      fontSize: 12 * scaleFactor,
                      fontWeight: FontWeight.bold,
                      color: LightModeColors.novoPharmaBlue,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8 * scaleFactor,
                      vertical: 4 * scaleFactor,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          SizedBox(height: 12 * scaleFactor),
          if (!hasPhotos && _isActiveSession)
            InkWell(
              onTap: _isUploadingPhoto ? null : _takeAndPreviewPhoto,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  vertical: 18 * scaleFactor,
                  horizontal: 14 * scaleFactor,
                ),
                decoration: BoxDecoration(
                  color: LightModeColors.novoPharmaLightBlue.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: LightModeColors.novoPharmaBlue.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10 * scaleFactor),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: _isUploadingPhoto
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.add_a_photo_rounded,
                              color: LightModeColors.novoPharmaBlue,
                              size: 20 * scaleFactor,
                            ),
                    ),
                    SizedBox(width: 12 * scaleFactor),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Ajouter des photos de la visite",
                            style: TextStyle(
                              fontSize: 13 * scaleFactor,
                              fontWeight: FontWeight.bold,
                              color: LightModeColors.dashboardTextPrimary,
                            ),
                          ),
                          SizedBox(height: 2 * scaleFactor),
                          Text(
                            "Photographiez vos vitrines, gondoles ou linéaires",
                            style: TextStyle(
                              fontSize: 11 * scaleFactor,
                              color: LightModeColors.novoPharmaGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13 * scaleFactor,
                      color: LightModeColors.novoPharmaBlue,
                    ),
                  ],
                ),
              ),
            )
          else if (!hasPhotos && !_isActiveSession)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8 * scaleFactor),
              child: Text(
                "Aucune photo enregistrée pour cette visite.",
                style: TextStyle(
                  fontSize: 12 * scaleFactor,
                  color: LightModeColors.novoPharmaGray,
                ),
              ),
            )
          else
            SizedBox(
              height: 90 * scaleFactor,
              child: Stack(
                children: [
                  ListView.separated(
                    controller: _photosScrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: totalItems,
                    separatorBuilder: (_, __) => SizedBox(width: 10 * scaleFactor),
                    itemBuilder: (context, idx) {
                      if (_isActiveSession && idx == 0) {
                        return GestureDetector(
                          onTap: _isUploadingPhoto ? null : _takeAndPreviewPhoto,
                          child: Container(
                            width: 85 * scaleFactor,
                            height: 90 * scaleFactor,
                            decoration: BoxDecoration(
                              color: LightModeColors.novoPharmaLightBlue.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: LightModeColors.novoPharmaBlue.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isUploadingPhoto)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                else
                                  Icon(
                                    Icons.add_a_photo_rounded,
                                    color: LightModeColors.novoPharmaBlue,
                                    size: 24 * scaleFactor,
                                  ),
                                SizedBox(height: 6 * scaleFactor),
                                Text(
                                  "Ajouter",
                                  style: TextStyle(
                                    fontSize: 11 * scaleFactor,
                                    fontWeight: FontWeight.bold,
                                    color: LightModeColors.novoPharmaBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final photoIndex = _isActiveSession ? idx - 1 : idx;
                      final photo = _visitPhotos[photoIndex];
                      final url = photo['url'] as String? ?? '';

                      return Stack(
                        children: [
                          GestureDetector(
                            onTap: () => _viewPhotoPopup(photoIndex),
                            child: Container(
                              width: 90 * scaleFactor,
                              height: 90 * scaleFactor,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.08),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: Colors.grey.shade100,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image_rounded, size: 24),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_isActiveSession)
                            Positioned(
                              top: 4 * scaleFactor,
                              right: 4 * scaleFactor,
                              child: GestureDetector(
                                onTap: () => _confirmDeletePhoto(photo),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (totalItems >= 4)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: AnimatedOpacity(
                        opacity: _canScrollRight ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: IgnorePointer(
                          ignoring: !_canScrollRight,
                          child: GestureDetector(
                            onTap: () {
                              if (_photosScrollController.hasClients) {
                                _photosScrollController.animateTo(
                                  (_photosScrollController.offset + 120 * scaleFactor)
                                      .clamp(
                                        0.0,
                                        _photosScrollController.position.maxScrollExtent,
                                      ),
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                );
                              }
                            },
                            child: Container(
                              alignment: Alignment.center,
                              padding: EdgeInsets.only(
                                left: 16 * scaleFactor,
                                right: 2 * scaleFactor,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.8),
                                    Colors.white,
                                  ],
                                ),
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              child: AnimatedBuilder(
                                animation: _arrowAnimation,
                                builder: (context, child) {
                                  return Transform.translate(
                                    offset: Offset(
                                      _arrowAnimation.value * scaleFactor,
                                      0,
                                    ),
                                    child: child,
                                  );
                                },
                                child: Container(
                                  width: 28 * scaleFactor,
                                  height: 28 * scaleFactor,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: LightModeColors.novoPharmaBlue,
                                    boxShadow: [
                                      BoxShadow(
                                        color: LightModeColors.novoPharmaBlue
                                            .withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: Colors.white,
                                      size: 13 * scaleFactor,
                                    ),
                                  ),
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
        ],
      ),
    );
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
                  color: Colors.black.withValues(alpha: 0.1),
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

  Future<void> _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint("Error launching phone: $e");
    }
  }

  Future<void> _openMap(String address, GeoPoint? location) async {
    Uri uri;
    if (location != null && location.latitude != 0 && location.longitude != 0) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}',
      );
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
      );
    }
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Error launching map: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final pharmacyName = _pharmacy?.name ?? widget.pharmacyName;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userProfile;
    final isDermo = user?.role == 'Dermo-conseiller';

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
                padding: EdgeInsets.symmetric(
                  horizontal: 18.0 * scaleFactor,
                  vertical: 16.0 * scaleFactor,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Unified Pharmacy Hero Card
                    _buildPharmacyHeroCard(pharmacyName, scaleFactor),
                    SizedBox(height: 16 * scaleFactor),

                    // 2. State-dependent sections:
                    if (!_isActiveSession) ...[
                      // Not active: either warning or check-in card
                      if (_globalActivePharmacyId != null && isDermo) ...[
                        _buildActiveElsewhereWarning(scaleFactor),
                        SizedBox(height: 16 * scaleFactor),
                      ] else if (_globalActivePharmacyId == null && isDermo) ...[
                        _buildCheckInCard(scaleFactor),
                        SizedBox(height: 16 * scaleFactor),
                      ],
                    ] else ...[
                      // Active Session: Visit Workflow Dashboard

                      // 2.1 Local Draft Notice (if any)
                      if (_hasLocalDraft) ...[
                        _buildDraftAlertBanner(scaleFactor),
                      ],

                      // 2.2 Visit Actions Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4 * scaleFactor,
                                height: 16 * scaleFactor,
                                decoration: BoxDecoration(
                                  color: LightModeColors.novoPharmaBlue,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              SizedBox(width: 8 * scaleFactor),
                              Text(
                                "Actions de la visite",
                                style: TextStyle(
                                  fontSize: 16 * scaleFactor,
                                  fontWeight: FontWeight.bold,
                                  color: LightModeColors.dashboardTextPrimary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8 * scaleFactor,
                              vertical: 3 * scaleFactor,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6 * scaleFactor,
                                  height: 6 * scaleFactor,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 4 * scaleFactor),
                                Text(
                                  "Visite active",
                                  style: TextStyle(
                                    fontSize: 11 * scaleFactor,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF047857),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12 * scaleFactor),

                      // 2.3 Ergonomic Quick Actions Grid
                      _buildVisitActionsGrid(isDermo, scaleFactor),
                      SizedBox(height: 16 * scaleFactor),

                      // 2.4 Visit Comment Display Card (if written)
                      if (_visitComment != null && _visitComment!.trim().isNotEmpty) ...[
                        _buildVisitCommentCard(scaleFactor),
                        SizedBox(height: 16 * scaleFactor),
                      ],

                      // 2.5 Photos Gallery Card
                      _buildPhotosGallery(scaleFactor),
                      SizedBox(height: 20 * scaleFactor),

                      // 2.6 Bottom Check-out Card
                      _buildCheckOutCard(scaleFactor),
                    ],

                    SizedBox(height: 50 * scaleFactor),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPharmacyHeroCard(String pharmacyName, double scaleFactor) {
    final hasPhone = _pharmacy != null && _pharmacy!.phone.trim().isNotEmpty;
    final hasAddress = _pharmacy != null && _pharmacy!.address.trim().isNotEmpty;
    final cityZone = _pharmacy != null ? "${_pharmacy!.city} / ${_pharmacy!.zone}".trim() : "";

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LightModeColors.lightOutlineVariant.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient Banner Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(18 * scaleFactor),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  LightModeColors.novoPharmaBlue,
                  LightModeColors.lightPrimary,
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(19),
                topRight: Radius.circular(19),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(10 * scaleFactor),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.local_hospital_rounded,
                        color: Colors.white,
                        size: 26 * scaleFactor,
                      ),
                    ),
                    SizedBox(width: 12 * scaleFactor),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pharmacyName,
                            style: TextStyle(
                              fontSize: 18 * scaleFactor,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (_pharmacy != null && _pharmacy!.clientCategory.isNotEmpty) ...[
                            SizedBox(height: 6 * scaleFactor),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8 * scaleFactor,
                                vertical: 3 * scaleFactor,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _pharmacy!.clientCategory,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11 * scaleFactor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Status Badge Pill
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10 * scaleFactor,
                        vertical: 5 * scaleFactor,
                      ),
                      decoration: BoxDecoration(
                        color: _isActiveSession
                            ? const Color(0xFF10B981)
                            : Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _isActiveSession
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6 * scaleFactor,
                            height: 6 * scaleFactor,
                            decoration: BoxDecoration(
                              color: _isActiveSession ? Colors.white : Colors.white70,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 5 * scaleFactor),
                          Text(
                            _isActiveSession ? "En visite" : "Non débutée",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11 * scaleFactor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_activePointOfSale != null && _activePointOfSale!.isNotEmpty) ...[
                  SizedBox(height: 12 * scaleFactor),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10 * scaleFactor,
                      vertical: 4 * scaleFactor,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront_rounded, color: Colors.white, size: 14 * scaleFactor),
                        SizedBox(width: 6 * scaleFactor),
                        Text(
                          "Point de vente : $_activePointOfSale",
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

          // Quick Information & Contact Strip
          Padding(
            padding: EdgeInsets.all(14 * scaleFactor),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16 * scaleFactor,
                      color: LightModeColors.novoPharmaBlue,
                    ),
                    SizedBox(width: 8 * scaleFactor),
                    Expanded(
                      child: Text(
                        hasAddress
                            ? "${_pharmacy!.address}${cityZone.isNotEmpty ? " • $cityZone" : ""}"
                            : (cityZone.isNotEmpty ? cityZone : "Adresse non spécifiée"),
                        style: TextStyle(
                          fontSize: 12 * scaleFactor,
                          color: LightModeColors.dashboardTextPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasPhone || hasAddress || _pharmacy?.location != null) ...[
                  SizedBox(height: 10 * scaleFactor),
                  Row(
                    children: [
                      if (hasPhone)
                        Expanded(
                          child: InkWell(
                            onTap: () => _callPhone(_pharmacy!.phone),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: 7 * scaleFactor,
                                horizontal: 10 * scaleFactor,
                              ),
                              decoration: BoxDecoration(
                                color: LightModeColors.novoPharmaLightBlue.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: LightModeColors.novoPharmaBlue.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.phone_rounded, size: 13 * scaleFactor, color: LightModeColors.novoPharmaBlue),
                                  SizedBox(width: 6 * scaleFactor),
                                  Flexible(
                                    child: Text(
                                      _pharmacy!.phone,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11 * scaleFactor,
                                        fontWeight: FontWeight.bold,
                                        color: LightModeColors.novoPharmaBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (hasPhone && (hasAddress || _pharmacy?.location != null))
                        SizedBox(width: 10 * scaleFactor),
                      if (hasAddress || _pharmacy?.location != null)
                        Expanded(
                          child: InkWell(
                            onTap: () => _openMap(
                              _pharmacy?.address ?? widget.pharmacyName,
                              _pharmacy?.location,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: 7 * scaleFactor,
                                horizontal: 10 * scaleFactor,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.directions_rounded, size: 14 * scaleFactor, color: LightModeColors.dashboardTextPrimary),
                                  SizedBox(width: 6 * scaleFactor),
                                  Text(
                                    "Itinéraire",
                                    style: TextStyle(
                                      fontSize: 11 * scaleFactor,
                                      fontWeight: FontWeight.bold,
                                      color: LightModeColors.dashboardTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftAlertBanner(double scaleFactor) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16 * scaleFactor),
      padding: EdgeInsets.all(14 * scaleFactor),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFB74D),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8 * scaleFactor),
            decoration: const BoxDecoration(
              color: Color(0xFFFFE082),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pending_actions_rounded,
              color: Color(0xFFE65100),
              size: 22,
            ),
          ),
          SizedBox(width: 12 * scaleFactor),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Brouillon d'audit non soumis",
                  style: TextStyle(
                    fontSize: 13 * scaleFactor,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFB71C1C),
                  ),
                ),
                SizedBox(height: 2 * scaleFactor),
                Text(
                  "Des lots saisis attendent votre révision.",
                  style: TextStyle(
                    fontSize: 11 * scaleFactor,
                    color: const Color(0xFF5D4037),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8 * scaleFactor),
          ElevatedButton(
            onPressed: () async {
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => StockReviewScreen(
                    pharmacyId: widget.pharmacyId,
                    pharmacyName: widget.pharmacyName,
                  ),
                ),
              );
              if (!mounted) return;
              _loadData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: 12 * scaleFactor,
                vertical: 8 * scaleFactor,
              ),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              "Réviser",
              style: TextStyle(
                fontSize: 12 * scaleFactor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitActionsGrid(bool isDermo, double scaleFactor) {
    return Column(
      children: [
        // Row 1: Audit Stock & Vente Manuelle
        Row(
          children: [
            _buildQuickActionCard(
              icon: Icons.inventory_2_rounded,
              iconColor: LightModeColors.novoPharmaBlue,
              iconBgColor: LightModeColors.novoPharmaLightBlue.withValues(alpha: 0.4),
              title: "Audit Stock",
              subtitle: "Inventaire & lots",
              badge: _hasLocalDraft
                  ? Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6 * scaleFactor,
                        vertical: 2 * scaleFactor,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFFB74D)),
                      ),
                      child: Text(
                        "Brouillon",
                        style: TextStyle(
                          color: const Color(0xFFE65100),
                          fontSize: 9 * scaleFactor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.arrow_forward_rounded,
                      size: 16 * scaleFactor,
                      color: LightModeColors.novoPharmaGray.withValues(alpha: 0.5),
                    ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StockBrandSelectionScreen(
                      pharmacyId: widget.pharmacyId,
                      pharmacyName: widget.pharmacyName,
                    ),
                  ),
                );
                if (!mounted) return;
                _loadData();
              },
              scaleFactor: scaleFactor,
            ),
            if (isDermo) ...[
              SizedBox(width: 12 * scaleFactor),
              _buildQuickActionCard(
                icon: Icons.shopping_cart_rounded,
                iconColor: const Color(0xFFEA580C),
                iconBgColor: const Color(0xFFFFEDD5),
                title: "Vente Manuelle",
                subtitle: "Saisir ventes",
                badge: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16 * scaleFactor,
                  color: LightModeColors.novoPharmaGray.withValues(alpha: 0.5),
                ),
                onTap: () async {
                  await Navigator.pushNamed(context, '/manual-sale');
                  if (!mounted) return;
                  _loadData();
                },
                scaleFactor: scaleFactor,
              ),
            ],
          ],
        ),
        SizedBox(height: 12 * scaleFactor),

        // Row 2: Note de Visite & Prendre Photo
        Row(
          children: [
            _buildQuickActionCard(
              icon: Icons.edit_note_rounded,
              iconColor: const Color(0xFF0D9488),
              iconBgColor: const Color(0xFFCCFBF1),
              title: "Commentaire",
              subtitle: (_visitComment != null && _visitComment!.trim().isNotEmpty)
                  ? "Note enregistrée"
                  : "Ajouter une note",
              badge: (_visitComment != null && _visitComment!.trim().isNotEmpty)
                  ? Icon(
                      Icons.check_circle_rounded,
                      size: 16 * scaleFactor,
                      color: const Color(0xFF0D9488),
                    )
                  : Icon(
                      Icons.add_circle_outline_rounded,
                      size: 16 * scaleFactor,
                      color: const Color(0xFF0D9488),
                    ),
              onTap: _showCommentDialog,
              scaleFactor: scaleFactor,
            ),
            SizedBox(width: 12 * scaleFactor),
            _buildQuickActionCard(
              icon: Icons.camera_alt_rounded,
              iconColor: const Color(0xFF7C3AED),
              iconBgColor: const Color(0xFFF3E8FF),
              title: "Prendre Photo",
              subtitle: _visitPhotos.isEmpty
                  ? "0 photo"
                  : "${_visitPhotos.length} photo${_visitPhotos.length > 1 ? 's' : ''}",
              badge: _isUploadingPhoto
                  ? SizedBox(
                      width: 14 * scaleFactor,
                      height: 14 * scaleFactor,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.add_a_photo_outlined,
                      size: 16 * scaleFactor,
                      color: const Color(0xFF7C3AED),
                    ),
              onTap: _isUploadingPhoto ? () {} : _takeAndPreviewPhoto,
              scaleFactor: scaleFactor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? badge,
    double scaleFactor = 1.0,
  }) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 110 * scaleFactor,
            padding: EdgeInsets.all(13 * scaleFactor),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: LightModeColors.lightOutlineVariant.withValues(alpha: 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8 * scaleFactor),
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: iconColor, size: 20 * scaleFactor),
                    ),
                    if (badge != null) badge,
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14 * scaleFactor,
                        fontWeight: FontWeight.bold,
                        color: LightModeColors.dashboardTextPrimary,
                      ),
                    ),
                    SizedBox(height: 2 * scaleFactor),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11 * scaleFactor,
                        color: LightModeColors.novoPharmaGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisitCommentCard(double scaleFactor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16 * scaleFactor),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0D9488).withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6 * scaleFactor),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.rate_review_outlined,
                      color: const Color(0xFF0D9488),
                      size: 16 * scaleFactor,
                    ),
                  ),
                  SizedBox(width: 8 * scaleFactor),
                  Text(
                    "Note de la visite",
                    style: TextStyle(
                      fontSize: 14 * scaleFactor,
                      fontWeight: FontWeight.bold,
                      color: LightModeColors.dashboardTextPrimary,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _showCommentDialog,
                icon: Icon(
                  Icons.edit_outlined,
                  size: 14 * scaleFactor,
                  color: LightModeColors.novoPharmaBlue,
                ),
                label: Text(
                  "Modifier",
                  style: TextStyle(
                    fontSize: 12 * scaleFactor,
                    fontWeight: FontWeight.bold,
                    color: LightModeColors.novoPharmaBlue,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8 * scaleFactor,
                    vertical: 4 * scaleFactor,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          SizedBox(height: 10 * scaleFactor),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12 * scaleFactor),
            decoration: BoxDecoration(
              color: LightModeColors.novoPharmaLightGray,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: LightModeColors.lightOutlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              _visitComment!,
              style: TextStyle(
                fontSize: 13 * scaleFactor,
                color: LightModeColors.dashboardTextPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckOutCard(double scaleFactor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16 * scaleFactor),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: LightModeColors.lightError.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: LightModeColors.lightError.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10 * scaleFactor),
                decoration: const BoxDecoration(
                  color: LightModeColors.lightErrorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.flag_rounded,
                  color: LightModeColors.lightError,
                  size: 20 * scaleFactor,
                ),
              ),
              SizedBox(width: 12 * scaleFactor),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Fin de visite",
                      style: TextStyle(
                        fontSize: 14 * scaleFactor,
                        fontWeight: FontWeight.bold,
                        color: LightModeColors.dashboardTextPrimary,
                      ),
                    ),
                    SizedBox(height: 2 * scaleFactor),
                    Text(
                      "Enregistrez votre départ et clôturez le rapport",
                      style: TextStyle(
                        fontSize: 11 * scaleFactor,
                        color: LightModeColors.novoPharmaGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14 * scaleFactor),
          SizedBox(
            width: double.infinity,
            height: 48 * scaleFactor,
            child: ElevatedButton.icon(
              onPressed: _isCheckingOut ? null : _handleCheckOut,
              icon: _isCheckingOut
                  ? SizedBox(
                      width: 18 * scaleFactor,
                      height: 18 * scaleFactor,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.logout_rounded, size: 18 * scaleFactor),
              label: Text(
                _isCheckingOut ? "Clôture en cours..." : "Effectuer le Check-out",
                style: TextStyle(
                  fontSize: 14 * scaleFactor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: LightModeColors.lightError,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInCard(double scaleFactor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20 * scaleFactor),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LightModeColors.novoPharmaBlue.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: LightModeColors.novoPharmaBlue.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(14 * scaleFactor),
            decoration: BoxDecoration(
              color: LightModeColors.novoPharmaLightBlue.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: LightModeColors.novoPharmaBlue,
              size: 32 * scaleFactor,
            ),
          ),
          SizedBox(height: 14 * scaleFactor),
          Text(
            "Démarrer votre visite",
            style: TextStyle(
              fontSize: 17 * scaleFactor,
              fontWeight: FontWeight.bold,
              color: LightModeColors.dashboardTextPrimary,
            ),
          ),
          SizedBox(height: 6 * scaleFactor),
          Text(
            "Validez votre arrivée pour débloquer l'audit de stock, la saisie des ventes et la prise de photos.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12 * scaleFactor,
              color: LightModeColors.novoPharmaGray,
              height: 1.4,
            ),
          ),
          SizedBox(height: 18 * scaleFactor),
          SizedBox(
            width: double.infinity,
            height: 50 * scaleFactor,
            child: ElevatedButton.icon(
              onPressed: _isCheckingIn ? null : _handleCheckIn,
              icon: _isCheckingIn
                  ? SizedBox(
                      width: 18 * scaleFactor,
                      height: 18 * scaleFactor,
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
                _isCheckingIn ? "Vérification GPS & Check-in..." : "Effectuer le Check-in",
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
        ],
      ),
    );
  }

  Widget _buildActiveElsewhereWarning(double scaleFactor) {
    return Container(
      padding: EdgeInsets.all(16 * scaleFactor),
      decoration: BoxDecoration(
        color: LightModeColors.lightErrorContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: LightModeColors.lightError.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: LightModeColors.lightError,
            size: 28 * scaleFactor,
          ),
          SizedBox(width: 12 * scaleFactor),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Visite déjà en cours ailleurs",
                  style: TextStyle(
                    fontSize: 13 * scaleFactor,
                    fontWeight: FontWeight.bold,
                    color: LightModeColors.lightError,
                  ),
                ),
                SizedBox(height: 3 * scaleFactor),
                Text(
                  "Vous êtes actuellement en visite à \"$_globalActivePharmacyName\". Effectuez d'abord votre check-out là-bas pour démarrer une visite ici.",
                  style: TextStyle(
                    fontSize: 12 * scaleFactor,
                    color: LightModeColors.lightOnErrorContainer,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
                color: LightModeColors.lightError.withValues(alpha: 0.08),
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
