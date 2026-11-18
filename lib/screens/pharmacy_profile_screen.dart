import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:novopharma/models/pharmacy.dart';
import 'package:novopharma/services/pharmacy_service.dart';
import 'package:novopharma/navigation_observer.dart';
import 'package:novopharma/design/design.dart';
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
import 'package:novopharma/controllers/basket_provider.dart';
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
    await showGlassDialog<void>(
      context: context,
      barrierDismissible: true,
      child: Builder(
        builder: (context) {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: BlisterIcon(
                      icon: Icons.location_off_rounded,
                      tone: Tone.coral,
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text("GPS désactivé", style: AppText.display(size: 22)),
                  const SizedBox(height: 8),
                  Text(
                    "Votre GPS semble être désactivé. Veuillez l'activer dans les paramètres de votre téléphone pour utiliser cette fonctionnalité.",
                    style: AppText.body(size: 14.5),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: "Paramètres",
                    icon: Icons.settings_rounded,
                    height: 52,
                    onPressed: () async {
                      Navigator.pop(context);
                      await Geolocator.openLocationSettings();
                    },
                  ),
                  const SizedBox(height: 10),
                  SecondaryButton(
                    label: "Annuler",
                    height: 48,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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

    final confirm = await showGlassDialog<bool>(
      context: context,
      barrierDismissible: true,
      padding: const EdgeInsets.all(22),
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      const BlisterIcon(
                        icon: Icons.location_on_rounded,
                        tone: Tone.mint,
                        size: 52,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          "Confirmer le Check-in",
                          style: AppText.display(size: 21),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Pharmacy card info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.66),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    child: Row(
                      children: [
                        const TintIcon(
                          icon: Icons.local_pharmacy_rounded,
                          tone: Tone.mint,
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Pharmacie cible",
                                style: AppText.label(size: 12),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.pharmacyName,
                                style: AppText.display(size: 16),
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
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Icon(
                          Icons.store_rounded,
                          size: 18,
                          color: AppColors.mintDeep,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Sélectionner le point de vente",
                            style: AppText.body(
                              size: 14.5,
                              weight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TonePill(
                          label: "${_pharmacy!.pointsOfSale.length}",
                          tone: Tone.mint,
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
                          return Semantics(
                            selected: isSelected,
                            child: Pressable(
                              onTap: () {
                                setDialogState(() {
                                  selectedPointOfSale = pos.name;
                                });
                              },
                              pressedScale: 0.98,
                              child: AnimatedContainer(
                                duration: AppMotion.fast,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.mintTint
                                      : Colors.white.withValues(alpha: 0.66),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.sm,
                                  ),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.mint
                                        : AppColors.line,
                                    width: isSelected ? 1.6 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.mint
                                            : AppColors.surfaceSunken,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.storefront_rounded,
                                        size: 17,
                                        color: isSelected
                                            ? AppColors.ink
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pos.name,
                                            style: AppText.body(
                                              size: 14.5,
                                              weight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                              height: 1.25,
                                            ),
                                          ),
                                          if (pos.city.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.place_outlined,
                                                  size: 13,
                                                  color: isSelected
                                                      ? AppColors.mintDeep
                                                      : AppColors.textMuted,
                                                ),
                                                const SizedBox(width: 3),
                                                Flexible(
                                                  child: Text(
                                                    pos.city,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: AppText.label(
                                                      size: 12.5,
                                                      color: isSelected
                                                          ? AppColors.mintDeep
                                                          : AppColors.textMuted,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked_rounded,
                                      size: 22,
                                      color: isSelected
                                          ? AppColors.mintDeep
                                          : AppColors.textFaint,
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
                    const SizedBox(height: 14),
                    Text(
                      "Voulez-vous enregistrer votre Check-in pour cette pharmacie ?",
                      style: AppText.body(size: 14.5),
                    ),
                  ],
                  const SizedBox(height: 22),
                  PrimaryButton.mint(
                    label: "Confirmer",
                    icon: Icons.check_rounded,
                    height: 52,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                  const SizedBox(height: 10),
                  SecondaryButton(
                    label: "Annuler",
                    height: 48,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
    final confirm = await showGlassDialog<bool>(
      context: context,
      barrierDismissible: true,
      child: Builder(
        builder: (context) {
          final double screenWidth = MediaQuery.of(context).size.width;
          final double scale = (screenWidth > 600) ? 1.4 : 1.0;
          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420 * scale),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      TintIcon(
                        icon: Icons.chat_bubble_outline_rounded,
                        tone: Tone.mint,
                        size: 44 * scale,
                      ),
                      SizedBox(width: 14 * scale),
                      Expanded(
                        child: Text(
                          "Ajouter un commentaire",
                          style: AppText.display(size: 20 * scale),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 18 * scale),
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Saisissez votre commentaire ici...",
                      hintStyle: AppText.body(
                        size: 15 * scale,
                        color: AppColors.textMuted,
                      ),
                      fillColor: Colors.white.withValues(alpha: 0.72),
                    ),
                    style: AppText.body(size: 15 * scale),
                  ),
                  SizedBox(height: 22 * scale),
                  PrimaryButton(
                    label: "Enregistrer",
                    icon: Icons.check_rounded,
                    height: 52 * scale,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                  SizedBox(height: 10 * scale),
                  SecondaryButton(
                    label: "Annuler",
                    height: 48 * scale,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
    final result = await showGlassDialog<String>(
      context: context,
      barrierDismissible: false,
      padding: const EdgeInsets.all(20),
      child: Builder(
        builder: (ctx) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Aperçu de la photo",
                        style: AppText.display(size: 20),
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx, 'cancel'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    child: Image.file(imageFile, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: "Confirmer",
                  icon: Icons.check_rounded,
                  height: 52,
                  onPressed: () => Navigator.pop(ctx, 'confirm'),
                ),
                const SizedBox(height: 10),
                SecondaryButton(
                  label: "Reprendre",
                  icon: Icons.refresh_rounded,
                  height: 48,
                  onPressed: () => Navigator.pop(ctx, 'retake'),
                ),
              ],
            ),
          );
        },
      ),
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

    final confirm = await showGlassDialog<bool>(
      context: context,
      barrierDismissible: true,
      child: Builder(
        builder: (ctx) {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: BlisterIcon(
                      icon: Icons.delete_forever_rounded,
                      tone: Tone.coral,
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "Supprimer la photo ?",
                    style: AppText.display(size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Êtes-vous sûr de vouloir supprimer définitivement cette photo de la visite ?",
                    style: AppText.body(size: 14.5),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton.coral(
                    label: "Supprimer",
                    icon: Icons.delete_outline_rounded,
                    height: 52,
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                  const SizedBox(height: 10),
                  SecondaryButton(
                    label: "Annuler",
                    height: 48,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
      barrierColor: AppColors.ink.withValues(alpha: 0.78),
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

            // Round control that stays readable over any photo.
            Widget navButton(
              IconData icon,
              String tooltip,
              VoidCallback onTap,
            ) {
              return Tooltip(
                message: tooltip,
                child: Pressable(
                  onTap: onTap,
                  pressedScale: 0.9,
                  semanticLabel: tooltip,
                  child: Container(
                    width: 44 * scale,
                    height: 44 * scale,
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20 * scale),
                  ),
                ),
              );
            }

            final softWhite = Colors.white.withValues(alpha: 0.78);

            return Center(
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: 18 * scale,
                  vertical: 24 * scale,
                ),
                constraints: BoxConstraints(
                  maxWidth: 520,
                  maxHeight: screenHeight * 0.82,
                ),
                // Smoked glass: a photo reads best on a dark frame.
                child: Glass(
                  style: GlassStyle.smoked,
                  blur: Glass.frost,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Popup Header
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            16 * scale,
                            10 * scale,
                            6 * scale,
                            10 * scale,
                          ),
                          child: Row(
                            children: [
                              TintIcon(
                                icon: Icons.photo_library_rounded,
                                tone: Tone.indigo,
                                size: 38 * scale,
                              ),
                              SizedBox(width: 12 * scale),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Photo ${currentIndex + 1} sur ${_visitPhotos.length}",
                                      style: AppText.display(
                                        size: 16 * scale,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (takenDate != null) ...[
                                      SizedBox(height: 3 * scale),
                                      Text(
                                        "${takenDate.day.toString().padLeft(2, '0')}/${takenDate.month.toString().padLeft(2, '0')}/${takenDate.year} à ${takenDate.hour.toString().padLeft(2, '0')}:${takenDate.minute.toString().padLeft(2, '0')}",
                                        style: AppText.label(
                                          size: 12 * scale,
                                          color: softWhite,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Delete Button (when session is active)
                              if (_isActiveSession && photo != null)
                                IconButton(
                                  tooltip: "Supprimer",
                                  onPressed: handleDeletePhoto,
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.coral,
                                    size: 22 * scale,
                                  ),
                                ),
                              // Close Button
                              IconButton(
                                tooltip: MaterialLocalizations.of(
                                  dialogCtx,
                                ).closeButtonTooltip,
                                onPressed: () => Navigator.pop(dialogCtx),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 22 * scale,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Image Area with PageView and Pinch-to-zoom
                        Flexible(
                          child: Container(
                            color: AppColors.ink,
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
                                            child: CapsuleLoader(
                                              left: Colors.white,
                                              right: AppColors.mintBright,
                                            ),
                                          ),
                                          errorWidget: (_, __, ___) => Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.broken_image_rounded,
                                                color: softWhite,
                                                size: 48 * scale,
                                              ),
                                              SizedBox(height: 8 * scale),
                                              Text(
                                                "Image indisponible",
                                                style: AppText.body(
                                                  size: 13 * scale,
                                                  color: softWhite,
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
                                    child: navButton(
                                      Icons.arrow_back_rounded,
                                      MaterialLocalizations.of(
                                        dialogCtx,
                                      ).previousPageTooltip,
                                      () {
                                        pageController.previousPage(
                                          duration: const Duration(milliseconds: 250),
                                          curve: Curves.easeInOut,
                                        );
                                      },
                                    ),
                                  ),

                                // Next Button
                                if (_visitPhotos.length > 1 && currentIndex < _visitPhotos.length - 1)
                                  Positioned(
                                    right: 10 * scale,
                                    child: navButton(
                                      Icons.arrow_forward_rounded,
                                      MaterialLocalizations.of(
                                        dialogCtx,
                                      ).nextPageTooltip,
                                      () {
                                        pageController.nextPage(
                                          duration: const Duration(milliseconds: 250),
                                          curve: Curves.easeInOut,
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Popup Footer
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            16 * scale,
                            4 * scale,
                            8 * scale,
                            4 * scale,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: 48 * scale),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.zoom_in_rounded,
                                  size: 16 * scale,
                                  color: softWhite,
                                ),
                                SizedBox(width: 6 * scale),
                                Expanded(
                                  child: Text(
                                    "Pincez pour zoomer • Glissez",
                                    style: AppText.label(
                                      size: 12 * scale,
                                      color: softWhite,
                                    ),
                                  ),
                                ),
                                if (_isActiveSession && photo != null)
                                  TextButton.icon(
                                    onPressed: handleDeletePhoto,
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18 * scale,
                                    ),
                                    label: const Text("Supprimer"),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.coral,
                                      iconColor: AppColors.coral,
                                      textStyle: AppText.body(
                                        size: 14 * scale,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SectionHeader(
                title: "Photos de la visite (${_visitPhotos.length})",
              ),
            ),
            if (_isActiveSession)
              _buildSectionAction(
                icon: Icons.add_a_photo_rounded,
                label: "Prendre",
                busy: _isUploadingPhoto,
                onTap: _isUploadingPhoto ? null : _takeAndPreviewPhoto,
                scaleFactor: scaleFactor,
              ),
          ],
        ),
        SizedBox(height: 8 * scaleFactor),
        SoftCard(
          radius: 24,
          padding: EdgeInsets.all(14 * scaleFactor),
          child: !hasPhotos && _isActiveSession
              ? Pressable(
                  onTap: _isUploadingPhoto ? null : _takeAndPreviewPhoto,
                  pressedScale: 0.98,
                  semanticLabel: "Ajouter des photos de la visite",
                  child: Row(
                    children: [
                      _isUploadingPhoto
                          ? SizedBox.square(
                              dimension: 46 * scaleFactor,
                              child: Center(
                                child: CapsuleLoader(size: 30 * scaleFactor),
                              ),
                            )
                          : TintIcon(
                              icon: Icons.add_a_photo_rounded,
                              tone: Tone.indigo,
                              size: 46 * scaleFactor,
                            ),
                      SizedBox(width: 12 * scaleFactor),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Ajouter des photos de la visite",
                              style: AppText.display(
                                size: 15.5 * scaleFactor,
                                height: 1.15,
                              ),
                            ),
                            SizedBox(height: 3 * scaleFactor),
                            Text(
                              "Photographiez vos vitrines, gondoles ou linéaires",
                              style: AppText.body(
                                size: 12.5 * scaleFactor,
                                color: AppColors.textMuted,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8 * scaleFactor),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 22 * scaleFactor,
                        color: AppColors.textFaint,
                      ),
                    ],
                  ),
                )
              : !hasPhotos && !_isActiveSession
              ? const EmptyState(
                  icon: Icons.photo_library_outlined,
                  title: "Aucune photo enregistrée pour cette visite.",
                )
              : SizedBox(
                  height: 92 * scaleFactor,
                  child: Stack(
                    children: [
                      ListView.separated(
                        controller: _photosScrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: totalItems,
                        separatorBuilder: (_, __) =>
                            SizedBox(width: 10 * scaleFactor),
                        itemBuilder: (context, idx) {
                          if (_isActiveSession && idx == 0) {
                            return Pressable(
                              onTap: _isUploadingPhoto
                                  ? null
                                  : _takeAndPreviewPhoto,
                              semanticLabel: "Ajouter",
                              child: Container(
                                width: 86 * scaleFactor,
                                height: 92 * scaleFactor,
                                decoration: BoxDecoration(
                                  color: AppColors.indigoTint,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.sm,
                                  ),
                                  border: Border.all(
                                    color: AppColors.indigo.withValues(
                                      alpha: 0.28,
                                    ),
                                    width: 1.4,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_isUploadingPhoto)
                                      CapsuleLoader(size: 26 * scaleFactor)
                                    else
                                      Icon(
                                        Icons.add_a_photo_rounded,
                                        color: AppColors.indigo,
                                        size: 24 * scaleFactor,
                                      ),
                                    SizedBox(height: 6 * scaleFactor),
                                    Text(
                                      "Ajouter",
                                      style: AppText.label(
                                        size: 12 * scaleFactor,
                                        weight: FontWeight.w700,
                                        color: AppColors.indigoDeep,
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
                              Pressable(
                                onTap: () => _viewPhotoPopup(photoIndex),
                                semanticLabel:
                                    "Photo ${photoIndex + 1} sur ${_visitPhotos.length}",
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.sm,
                                  ),
                                  child: SizedBox(
                                    width: 92 * scaleFactor,
                                    height: 92 * scaleFactor,
                                    child: CachedNetworkImage(
                                      imageUrl: url,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const Shimmer(
                                        child: SkeletonBox(
                                          width: double.infinity,
                                          height: double.infinity,
                                          radius: 0,
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) =>
                                          const ColoredBox(
                                            color: AppColors.surfaceSunken,
                                            child: Center(
                                              child: Icon(
                                                Icons.broken_image_rounded,
                                                size: 24,
                                                color: AppColors.textFaint,
                                              ),
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_isActiveSession)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Pressable(
                                    onTap: () => _confirmDeletePhoto(photo),
                                    pressedScale: 0.9,
                                    semanticLabel: "Supprimer",
                                    // A 44pt target around a small glyph.
                                    child: SizedBox.square(
                                      dimension: 44,
                                      child: Align(
                                        alignment: Alignment.topRight,
                                        child: Container(
                                          margin: const EdgeInsets.all(5),
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: AppColors.ink.withValues(
                                              alpha: 0.62,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close_rounded,
                                            color: Colors.white,
                                            size: 15,
                                          ),
                                        ),
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
                              child: Pressable(
                                semanticLabel: MaterialLocalizations.of(
                                  context,
                                ).nextPageTooltip,
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
                                    left: 18 * scaleFactor,
                                    right: 2 * scaleFactor,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.0),
                                        Colors.white.withValues(alpha: 0.82),
                                        Colors.white.withValues(alpha: 0.94),
                                      ],
                                    ),
                                    borderRadius: const BorderRadius.horizontal(
                                      right: Radius.circular(AppRadii.sm),
                                    ),
                                  ),
                                  child: AnimatedBuilder(
                                    animation: _arrowAnimation,
                                    builder: (context, child) {
                                      return Transform.translate(
                                        offset: Offset(
                                          AppMotion.reduced(context)
                                              ? 0
                                              : _arrowAnimation.value * scaleFactor,
                                          0,
                                        ),
                                        child: child,
                                      );
                                    },
                                    child: Container(
                                      width: 30 * scaleFactor,
                                      height: 30 * scaleFactor,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: AppGradients.indigo,
                                        boxShadow: AppShadows.glow(
                                          AppColors.indigo,
                                          strength: 0.3,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 16 * scaleFactor,
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
        ),
      ],
    );
  }

  /// A compact text action for a section title, sized for a thumb.
  Widget _buildSectionAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required double scaleFactor,
    bool busy = false,
  }) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 44 * scaleFactor),
        child: Padding(
          padding: EdgeInsets.only(
            left: 10 * scaleFactor,
            right: 2 * scaleFactor,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                CapsuleLoader(size: 20 * scaleFactor)
              else
                Icon(icon, size: 18 * scaleFactor, color: AppColors.indigo),
              SizedBox(width: 6 * scaleFactor),
              Text(
                label,
                style: AppText.label(
                  size: 14 * scaleFactor,
                  weight: FontWeight.w700,
                  color: AppColors.indigo,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCheckOut() async {
    if (_activeVisitId == null) return;

    final basketProvider = Provider.of<BasketProvider>(context, listen: false);
    if (basketProvider.hasOpenBasket) {
      showGlassDialog<void>(
        context: context,
        child: Builder(
          builder: (ctx) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: BlisterIcon(
                    icon: Icons.shopping_basket_rounded,
                    tone: Tone.peach,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Panier en cours",
                  textAlign: TextAlign.center,
                  style: AppText.display(size: 21),
                ),
                const SizedBox(height: 10),
                Text(
                  "Vous avez un panier ouvert contenant ${basketProvider.totalItemsCount} article(s). Veuillez le clôturer ou l'annuler avant d'effectuer le check-out.",
                  textAlign: TextAlign.center,
                  style: AppText.body(
                    size: 14.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 22),
                PrimaryButton(
                  label: "Voir le panier",
                  icon: Icons.shopping_cart_rounded,
                  gradient: Tone.peach.gradient,
                  glowColor: AppColors.peach,
                  foreground: AppColors.ink,
                  height: 52,
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/basket');
                  },
                ),
                const SizedBox(height: 10),
                SecondaryButton(
                  label: "Fermer",
                  height: 48,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    final confirm = await showGlassDialog<bool>(
      context: context,
      barrierDismissible: true,
      child: Builder(
        builder: (context) {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: BlisterIcon(
                      icon: Icons.logout_rounded,
                      tone: Tone.coral,
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "Confirmer le Check-out",
                    style: AppText.display(size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Voulez-vous vraiment enregistrer votre Check-out et terminer votre visite ?",
                    style: AppText.body(size: 14.5),
                  ),
                  if (_visitComment == null || _visitComment!.trim().isEmpty) ...[
                    const SizedBox(height: 16),
                    SecondaryButton(
                      label: "Ajouter un commentaire",
                      icon: Icons.chat_bubble_outline_rounded,
                      tone: Tone.mint,
                      height: 48,
                      onPressed: () {
                        Navigator.pop(context, false);
                        _showCommentDialog();
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  PrimaryButton.coral(
                    label: "Déconnexion",
                    icon: Icons.logout_rounded,
                    height: 52,
                    onPressed: () => Navigator.pop(context, true),
                  ),
                  const SizedBox(height: 10),
                  SecondaryButton(
                    label: "Annuler",
                    height: 48,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
        // The wrapper paints the pastel canvas; this page stays clear glass.
        backgroundColor: Colors.transparent,
        // Builder: below the wrapper, the bottom padding is the height of
        // the glass dock the page scrolls under.
        body: Builder(
          builder: (context) => SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ink hero: the pharmacy and the state of the visit.
                InkHero(
                  padding: EdgeInsets.fromLTRB(
                    AppSpace.page * scaleFactor,
                    10,
                    AppSpace.page * scaleFactor,
                    24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Entrance(
                        offset: const Offset(0, -12),
                        child: Row(
                          children: [
                            GlassIconButton(
                              icon: Icons.arrow_back_rounded,
                              tooltip: MaterialLocalizations.of(
                                context,
                              ).backButtonTooltip,
                              onTap: () {
                                if (_isActiveSession) {
                                  Navigator.of(
                                    context,
                                  ).pushNamedAndRemoveUntil('/dashboard_home', (route) => false);
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Profil de la Pharmacie",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.display(
                                  size: 19 * scaleFactor,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (_isActiveSession) ...[
                              const SizedBox(width: 8),
                              _isCheckingOut
                                  ? const SizedBox.square(
                                      dimension: 44,
                                      child: Center(
                                        child: CapsuleLoader(
                                          size: 28,
                                          left: Colors.white,
                                          right: AppColors.mintBright,
                                        ),
                                      ),
                                    )
                                  : GlassIconButton(
                                      icon: Icons.logout_rounded,
                                      tooltip: "Check-out",
                                      onTap: _handleCheckOut,
                                    ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 18 * scaleFactor),

                      // 1. Pharmacy identity and visit status
                      _buildPharmacyHeroCard(pharmacyName, scaleFactor),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpace.page * scaleFactor,
                    22 * scaleFactor,
                    AppSpace.page * scaleFactor,
                    0,
                  ),
                  // One arrival for the canvas; later reloads swap in place.
                  child: Entrance(
                    delay: const Duration(milliseconds: 280),
                    child: _isLoading
                        ? Shimmer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: SkeletonBox(width: 190, height: 22),
                                ),
                                SizedBox(height: 14 * scaleFactor),
                                for (var i = 0; i < 2; i++) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SkeletonBox(
                                          height: 112 * scaleFactor,
                                          radius: 24,
                                        ),
                                      ),
                                      SizedBox(width: 12 * scaleFactor),
                                      Expanded(
                                        child: SkeletonBox(
                                          height: 112 * scaleFactor,
                                          radius: 24,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12 * scaleFactor),
                                ],
                                SizedBox(height: 12 * scaleFactor),
                                SkeletonBox(
                                  height: 120 * scaleFactor,
                                  radius: 24,
                                ),
                              ],
                            ),
                          )
                        : _locationPermissionGranted == false
                        ? _buildGPSBlocker()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
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
                                  children: [
                                    const Expanded(
                                      child: SectionHeader(
                                        title: "Actions de la visite",
                                      ),
                                    ),
                                    SizedBox(width: 8 * scaleFactor),
                                    const TonePill(
                                      label: "Visite active",
                                      tone: Tone.mint,
                                      icon: Icons.fiber_manual_record_rounded,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12 * scaleFactor),

                                // 2.3 Ergonomic Quick Actions Grid
                                _buildVisitActionsGrid(isDermo, scaleFactor),
                                SizedBox(height: 24 * scaleFactor),

                                // 2.4 Visit Comment Display Card (if written)
                                if (_visitComment != null && _visitComment!.trim().isNotEmpty) ...[
                                  _buildVisitCommentCard(scaleFactor),
                                  SizedBox(height: 24 * scaleFactor),
                                ],

                                // 2.5 Photos Gallery Card
                                _buildPhotosGallery(scaleFactor),
                                SizedBox(height: 28 * scaleFactor),

                                // 2.6 Bottom Check-out Card
                                _buildCheckOutCard(scaleFactor),
                              ],
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The hero's content on ink: the pharmacy's name, the visit status in a
  /// dark glass card, then how to reach the place.
  Widget _buildPharmacyHeroCard(String pharmacyName, double scaleFactor) {
    final hasPhone = _pharmacy != null && _pharmacy!.phone.trim().isNotEmpty;
    final hasAddress = _pharmacy != null && _pharmacy!.address.trim().isNotEmpty;
    final cityZone = _pharmacy != null ? "${_pharmacy!.city} / ${_pharmacy!.zone}".trim() : "";
    // The visit state is only known once the first load has gone through.
    final showVisit = _locationPermissionGranted && !(_isLoading && _pharmacy == null);
    final soft = Colors.white.withValues(alpha: 0.86);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Entrance(
          delay: const Duration(milliseconds: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pharmacyName,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.display(
                  size: 28 * scaleFactor,
                  color: Colors.white,
                ),
              ),
              if (_pharmacy != null && _pharmacy!.clientCategory.isNotEmpty) ...[
                SizedBox(height: 10 * scaleFactor),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10 * scaleFactor,
                    vertical: 5 * scaleFactor,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    _pharmacy!.clientCategory,
                    style: AppText.label(
                      size: 12 * scaleFactor,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showVisit) ...[
          SizedBox(height: 16 * scaleFactor),

          // Visit status, live
          Entrance(
            delay: const Duration(milliseconds: 160),
            scaleFrom: 0.96,
            child: SoftCard(
              style: GlassStyle.dark,
              blur: Glass.frost,
              radius: AppRadii.md,
              padding: EdgeInsets.all(14 * scaleFactor),
              child: Row(
                children: [
                  BlisterIcon(
                    icon: Icons.local_pharmacy_rounded,
                    tone: Tone.mint,
                    size: 46 * scaleFactor,
                    glow: _isActiveSession,
                  ),
                  SizedBox(width: 12 * scaleFactor),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // The "live" dot
                            Container(
                              width: 9 * scaleFactor,
                              height: 9 * scaleFactor,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isActiveSession
                                    ? AppColors.mintBright
                                    : Colors.white.withValues(alpha: 0.5),
                                boxShadow: _isActiveSession
                                    ? [
                                        BoxShadow(
                                          color: AppColors.mint.withValues(
                                            alpha: 0.8,
                                          ),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            SizedBox(width: 8 * scaleFactor),
                            Flexible(
                              child: Text(
                                _isActiveSession ? "En visite" : "Non débutée",
                                style: AppText.display(
                                  size: 18 * scaleFactor,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_activePointOfSale != null && _activePointOfSale!.isNotEmpty) ...[
                          SizedBox(height: 5 * scaleFactor),
                          Row(
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                color: soft,
                                size: 15 * scaleFactor,
                              ),
                              SizedBox(width: 6 * scaleFactor),
                              Expanded(
                                child: Text(
                                  "Point de vente : $_activePointOfSale",
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body(
                                    size: 13.5 * scaleFactor,
                                    weight: FontWeight.w600,
                                    color: soft,
                                    height: 1.25,
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
            ),
          ),
          SizedBox(height: 14 * scaleFactor),

          // Quick Information & Contact Strip
          Entrance(
            delay: const Duration(milliseconds: 220),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.location_on_outlined,
                        size: 17 * scaleFactor,
                        color: soft,
                      ),
                    ),
                    SizedBox(width: 8 * scaleFactor),
                    Expanded(
                      child: Text(
                        hasAddress
                            ? "${_pharmacy!.address}${cityZone.isNotEmpty ? " • $cityZone" : ""}"
                            : (cityZone.isNotEmpty ? cityZone : "Adresse non spécifiée"),
                        style: AppText.body(
                          size: 13.5 * scaleFactor,
                          color: soft,
                          weight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasPhone || hasAddress || _pharmacy?.location != null) ...[
                  SizedBox(height: 12 * scaleFactor),
                  Wrap(
                    spacing: 10 * scaleFactor,
                    runSpacing: 8 * scaleFactor,
                    children: [
                      if (hasPhone)
                        _buildHeroChip(
                          icon: Icons.phone_rounded,
                          label: _pharmacy!.phone,
                          onTap: () => _callPhone(_pharmacy!.phone),
                          scaleFactor: scaleFactor,
                        ),
                      if (hasAddress || _pharmacy?.location != null)
                        _buildHeroChip(
                          icon: Icons.directions_rounded,
                          label: "Itinéraire",
                          onTap: () => _openMap(
                            _pharmacy?.address ?? widget.pharmacyName,
                            _pharmacy?.location,
                          ),
                          scaleFactor: scaleFactor,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// A compact dark-glass pill for the hero's contact actions.
  Widget _buildHeroChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required double scaleFactor,
  }) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Glass(
        style: GlassStyle.dark,
        shadow: false,
        height: 44 * scaleFactor,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        padding: EdgeInsets.symmetric(horizontal: 14 * scaleFactor),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17 * scaleFactor, color: Colors.white),
            SizedBox(width: 7 * scaleFactor),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(
                  size: 14 * scaleFactor,
                  weight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftAlertBanner(double scaleFactor) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20 * scaleFactor),
      child: SoftCard(
        tint: AppColors.amberTint,
        radius: 24,
        padding: EdgeInsets.all(14 * scaleFactor),
        onTap: () async {
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
        child: Row(
          children: [
            BlisterIcon(
              icon: Icons.pending_actions_rounded,
              tone: Tone.amber,
              size: 42 * scaleFactor,
              glow: false,
            ),
            SizedBox(width: 12 * scaleFactor),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Brouillon d'audit non soumis",
                    style: AppText.display(
                      size: 15.5 * scaleFactor,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 3 * scaleFactor),
                  Text(
                    "Des lots saisis attendent votre révision.",
                    style: AppText.body(
                      size: 12.5 * scaleFactor,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10 * scaleFactor),
            // The card is the button; this pill names what a tap does.
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12 * scaleFactor,
                vertical: 8 * scaleFactor,
              ),
              decoration: BoxDecoration(
                gradient: AppGradients.amber,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                "Réviser",
                style: AppText.label(
                  size: 13 * scaleFactor,
                  weight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitActionsGrid(bool isDermo, double scaleFactor) {
    final chevron = Icon(
      Icons.chevron_right_rounded,
      size: 22 * scaleFactor,
      color: AppColors.textFaint,
    );
    final hasComment = _visitComment != null && _visitComment!.trim().isNotEmpty;

    return Column(
      children: [
        // Row 1: Audit Stock & Vente Manuelle
        Row(
          children: [
            _buildQuickActionCard(
              icon: Icons.inventory_2_rounded,
              tone: Tone.amber,
              title: "Audit Stock",
              subtitle: "Inventaire & lots",
              badge: _hasLocalDraft
                  ? const TonePill(label: "Brouillon", tone: Tone.amber)
                  : chevron,
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
                tone: Tone.peach,
                title: "Vente Manuelle",
                subtitle: "Saisir ventes",
                badge: chevron,
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
              tone: Tone.mint,
              title: "Commentaire",
              subtitle: hasComment ? "Note enregistrée" : "Ajouter une note",
              badge: Icon(
                hasComment
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                size: 20 * scaleFactor,
                color: AppColors.mintDeep,
              ),
              onTap: _showCommentDialog,
              scaleFactor: scaleFactor,
            ),
            SizedBox(width: 12 * scaleFactor),
            _buildQuickActionCard(
              icon: Icons.camera_alt_rounded,
              tone: Tone.indigo,
              title: "Prendre Photo",
              subtitle: _visitPhotos.isEmpty
                  ? "0 photo"
                  : "${_visitPhotos.length} photo${_visitPhotos.length > 1 ? 's' : ''}",
              badge: _isUploadingPhoto
                  ? CapsuleLoader(size: 22 * scaleFactor)
                  : Icon(
                      Icons.add_a_photo_outlined,
                      size: 20 * scaleFactor,
                      color: AppColors.indigo,
                    ),
              onTap: _isUploadingPhoto ? () {} : _takeAndPreviewPhoto,
              scaleFactor: scaleFactor,
            ),
          ],
        ),
      ],
    );
  }

  /// One glass tile of the visit's actions. [tone] is the feature's accent.
  Widget _buildQuickActionCard({
    required IconData icon,
    required Tone tone,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? badge,
    double scaleFactor = 1.0,
  }) {
    return Expanded(
      child: SoftCard(
        onTap: onTap,
        semanticLabel: title,
        radius: 24,
        padding: EdgeInsets.all(14 * scaleFactor),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TintIcon(icon: icon, tone: tone, size: 42 * scaleFactor),
                if (badge != null)
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.only(left: 6 * scaleFactor),
                      child: FittedBox(fit: BoxFit.scaleDown, child: badge),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16 * scaleFactor),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.display(size: 16 * scaleFactor),
            ),
            SizedBox(height: 3 * scaleFactor),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label(size: 12.5 * scaleFactor, letterSpacing: 0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitCommentCard(double scaleFactor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: "Note de la visite")),
            _buildSectionAction(
              icon: Icons.edit_rounded,
              label: "Modifier",
              onTap: _showCommentDialog,
              scaleFactor: scaleFactor,
            ),
          ],
        ),
        SizedBox(height: 8 * scaleFactor),
        SoftCard(
          radius: 24,
          padding: EdgeInsets.all(16 * scaleFactor),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TintIcon(
                icon: Icons.rate_review_rounded,
                tone: Tone.mint,
                size: 40 * scaleFactor,
              ),
              SizedBox(width: 12 * scaleFactor),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 2 * scaleFactor),
                  child: Text(
                    _visitComment!,
                    style: AppText.body(size: 14.5 * scaleFactor, height: 1.45),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckOutCard(double scaleFactor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: "Fin de visite"),
        SizedBox(height: 10 * scaleFactor),
        SoftCard(
          padding: EdgeInsets.all(16 * scaleFactor),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TintIcon(
                    icon: Icons.flag_rounded,
                    tone: Tone.coral,
                    size: 42 * scaleFactor,
                  ),
                  SizedBox(width: 12 * scaleFactor),
                  Expanded(
                    child: Text(
                      "Enregistrez votre départ et clôturez le rapport",
                      style: AppText.body(
                        size: 14 * scaleFactor,
                        color: AppColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16 * scaleFactor),
              AnimatedSwitcher(
                duration: AppMotion.fast,
                child: _isCheckingOut
                    ? _buildBusyRow("Clôture en cours...", scaleFactor)
                    : PrimaryButton.coral(
                        key: const ValueKey('check-out'),
                        label: "Effectuer le Check-out",
                        icon: Icons.logout_rounded,
                        height: 56 * scaleFactor,
                        onPressed: _handleCheckOut,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckInCard(double scaleFactor) {
    return SoftCard(
      padding: EdgeInsets.all(20 * scaleFactor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BlisterIcon(
                icon: Icons.location_on_rounded,
                tone: Tone.mint,
                size: 54 * scaleFactor,
              ),
              SizedBox(width: 14 * scaleFactor),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Démarrer votre visite",
                      style: AppText.display(size: 20 * scaleFactor),
                    ),
                    SizedBox(height: 6 * scaleFactor),
                    Text(
                      "Validez votre arrivée pour débloquer l'audit de stock, la saisie des ventes et la prise de photos.",
                      style: AppText.body(
                        size: 13.5 * scaleFactor,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 18 * scaleFactor),
          AnimatedSwitcher(
            duration: AppMotion.fast,
            child: _isCheckingIn
                ? _buildBusyRow("Vérification GPS & Check-in...", scaleFactor)
                : PrimaryButton.mint(
                    key: const ValueKey('check-in'),
                    label: "Effectuer le Check-in",
                    icon: Icons.login_rounded,
                    height: 56 * scaleFactor,
                    onPressed: _handleCheckIn,
                  ),
          ),
        ],
      ),
    );
  }

  /// What a check-in / check-out button turns into while it runs: the
  /// capsule loader beside the words that say what is happening.
  Widget _buildBusyRow(String label, double scaleFactor) {
    return SizedBox(
      key: ValueKey(label),
      height: 56 * scaleFactor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CapsuleLoader(size: 30 * scaleFactor),
          SizedBox(width: 12 * scaleFactor),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(
                size: 15 * scaleFactor,
                weight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveElsewhereWarning(double scaleFactor) {
    return SoftCard(
      tint: AppColors.coralTint,
      radius: 24,
      padding: EdgeInsets.all(16 * scaleFactor),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlisterIcon(
            icon: Icons.warning_amber_rounded,
            tone: Tone.coral,
            size: 42 * scaleFactor,
            glow: false,
          ),
          SizedBox(width: 12 * scaleFactor),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Visite déjà en cours ailleurs",
                  style: AppText.display(
                    size: 16 * scaleFactor,
                    color: AppColors.coralDeep,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 4 * scaleFactor),
                Text(
                  "Vous êtes actuellement en visite à \"$_globalActivePharmacyName\". Effectuez d'abord votre check-out là-bas pour démarrer une visite ici.",
                  style: AppText.body(size: 13.5 * scaleFactor, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGPSBlocker() {
    return EmptyState(
      icon: Icons.location_off_rounded,
      tone: Tone.coral,
      title: "Localisation GPS Requise",
      message:
          "L'accès à la position GPS de votre téléphone est requis pour afficher le profil de la pharmacie et effectuer le Check-out.",
      actionLabel: "Autoriser / Réessayer",
      onAction: _loadData,
    );
  }
}
