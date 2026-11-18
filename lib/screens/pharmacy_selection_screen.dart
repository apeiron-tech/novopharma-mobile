import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novopharma/models/pharmacy.dart';
import 'package:novopharma/services/pharmacy_service.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:novopharma/design/design.dart';
import 'package:novopharma/screens/pharmacy_profile_screen.dart';
import 'package:novopharma/widgets/bottom_navigation_bar.dart';


class PharmacySelectionScreen extends StatefulWidget {
  const PharmacySelectionScreen({super.key});

  @override
  State<PharmacySelectionScreen> createState() => _PharmacySelectionScreenState();
}

class _PharmacySelectionScreenState extends State<PharmacySelectionScreen> {
  final PharmacyService _pharmacyService = PharmacyService();
  List<Pharmacy> _allPharmacies = [];
  List<Pharmacy> _filteredPharmacies = [];
  bool _isLoading = true;
  String? _errorMessage;

  Position? _currentPosition;
  bool _locationPermissionGranted = false;

  // Nearby filter state
  bool _isNearbyOnly = false;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initLocationAndFetchPharmacies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
    _applyFilters();
  }

  Future<void> _initLocationAndFetchPharmacies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      bool hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        setState(() {
          _locationPermissionGranted = false;
          _isLoading = false;
        });
        return;
      }

      _locationPermissionGranted = true;
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // Fetch pharmacies
      _allPharmacies = await _pharmacyService.getPharmacies();
      _applyFilters();
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur de chargement: $e";
      });
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

  void _applyFilters() {
    List<Pharmacy> temp = [];

    // 1. Filter by location (nearby 1 km vs all)
    if (_isNearbyOnly) {
      if (_locationPermissionGranted && _currentPosition != null) {
        final double userLat = _currentPosition!.latitude;
        final double userLng = _currentPosition!.longitude;
        temp = _allPharmacies.where((pharmacy) {
          if (pharmacy.location.latitude == 0.0 && pharmacy.location.longitude == 0.0) {
            return false;
          }
          double distanceInMeters = Geolocator.distanceBetween(
            userLat,
            userLng,
            pharmacy.location.latitude,
            pharmacy.location.longitude,
          );
          return distanceInMeters <= 1000.0;
        }).toList();
      } else {
        temp = [];
      }
    } else {
      // Default: Display ALL pharmacies
      temp = List.from(_allPharmacies);
    }

    // 2. Filter by search query
    if (_searchQuery.isNotEmpty) {
      temp = temp.where((pharmacy) {
        return pharmacy.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               pharmacy.address.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    setState(() {
      _filteredPharmacies = temp;
    });
  }

  Future<void> _toggleNearbyFilter() async {
    if (!_isNearbyOnly) {
      if (!_locationPermissionGranted || _currentPosition == null) {
        bool ok = await _checkLocationPermission();
        if (ok) {
          _currentPosition = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );
          _locationPermissionGranted = true;
        } else {
          return;
        }
      }
      setState(() {
        _isNearbyOnly = true;
      });
    } else {
      setState(() {
        _isNearbyOnly = false;
      });
    }
    _applyFilters();
  }

  Future<void> _handleCheckIn(Pharmacy pharmacy) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userProfile;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session utilisateur introuvable")),
      );
      return;
    }

    try {
      final activeVisitsQuery = await FirebaseFirestore.instance
          .collection('visits_history')
          .where('dermoId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .get();

      if (activeVisitsQuery.docs.length > 1) {
        if (mounted) {
          showGlassDialog<void>(
            context: context,
            child: Builder(
              builder: (context) => ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: BlisterIcon(
                        icon: Icons.error_outline_rounded,
                        tone: Tone.coral,
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Visites actives multiples",
                      textAlign: TextAlign.center,
                      style: AppText.display(size: 21),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Vous avez plusieurs visites actives enregistrées. Veuillez fermer vos anciennes visites ou contacter votre responsable pour les fermer.",
                      textAlign: TextAlign.center,
                      style: AppText.body(
                        size: 14.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      label: "OK",
                      height: 50,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint("Error checking active visits before check-in: $e");
    }

    String? selectedPointOfSale;
    final bool hasPOS = pharmacy.hasPointsOfSale && pharmacy.pointsOfSale.isNotEmpty;
    if (hasPOS) {
      selectedPointOfSale = pharmacy.pointsOfSale.first.name;
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
                                pharmacy.name,
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
                          label: "${pharmacy.pointsOfSale.length}",
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
                        itemCount: pharmacy.pointsOfSale.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final pos = pharmacy.pointsOfSale[idx];
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
    if (hasPOS && (selectedPointOfSale == null || selectedPointOfSale!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez sélectionner un point de vente")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      GeoPoint checkInGeoPoint = const GeoPoint(0, 0);
      try {
        if (_locationPermissionGranted) {
          Position pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );
          checkInGeoPoint = GeoPoint(pos.latitude, pos.longitude);
        }
      } catch (e) {
        debugPrint("Error fetching exact check-in location: $e");
      }

      final docRef = FirebaseFirestore.instance.collection('visits_history').doc();
      final visitId = docRef.id;

      final checkInData = {
        'visitId': visitId,
        'dermoId': user.uid,
        'pharmacyId': pharmacy.id,
        'pharmacyName': pharmacy.name,
        if (selectedPointOfSale != null) 'pointOfSale': selectedPointOfSale,
        'checkInLocation': checkInGeoPoint,
        'checkInTime': FieldValue.serverTimestamp(),
        'checkOutTime': null,
        'status': 'active',
      };

      await docRef.set(checkInData);

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_visit_id', visitId);
      await prefs.setString('active_pharmacy_id', pharmacy.id);
      await prefs.setString('active_pharmacy_name', pharmacy.name);
      if (selectedPointOfSale != null) {
        await prefs.setString('active_point_of_sale', selectedPointOfSale!);
      } else {
        await prefs.remove('active_point_of_sale');
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PharmacyProfileScreen(
              pharmacyId: pharmacy.id,
              pharmacyName: pharmacy.name,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors du Check-in: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationScaffoldWrapper(
      currentIndex: 0,
      onTap: (index) {},
      child: Scaffold(
        // The wrapper paints the pastel canvas; this page stays clear glass.
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ink hero: where you are, and the search that narrows the list.
            InkHero(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.page,
                10,
                AppSpace.page,
                22,
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
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Sélection Pharmacie",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.display(
                              size: 24,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Search bar. Shown but inert while the list is loading, so
                  // the hero keeps its height; hidden when GPS is blocked.
                  if (_isLoading || _locationPermissionGranted) ...[
                    const SizedBox(height: 18),
                    Entrance(
                      delay: const Duration(milliseconds: 80),
                      child: IgnorePointer(
                        ignoring: _isLoading,
                        child: AnimatedOpacity(
                          duration: AppMotion.fast,
                          opacity: _isLoading ? 0.55 : 1,
                          child: AppSearchField(
                            controller: _searchController,
                            onDark: true,
                            hintText:
                                "Rechercher une pharmacie par nom ou adresse...",
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Entrance(
                delay: const Duration(milliseconds: 160),
                // Builder: below the wrapper, the bottom padding is the
                // height of the glass dock the list scrolls under.
                child: Builder(
                  builder: (context) {
                    final dockInset = MediaQuery.paddingOf(context).bottom;
                    return _isLoading
                        ? (_allPharmacies.isEmpty
                              ? SkeletonList(
                                  count: 6,
                                  itemHeight: 84,
                                  padding: EdgeInsets.fromLTRB(
                                    20,
                                    20,
                                    20,
                                    dockInset + 20,
                                  ),
                                )
                              : Padding(
                                  padding: EdgeInsets.only(bottom: dockInset),
                                  child: const Center(child: CapsuleLoader()),
                                ))
                        : !_locationPermissionGranted
                        ? _buildGPSBlocker()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Filter pills: all pharmacies or within 1 km
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  16,
                                  20,
                                  0,
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    // Pill 1: Toutes
                                    SelectPill(
                                      label: "Toutes",
                                      icon: Icons.storefront_rounded,
                                      selected: !_isNearbyOnly,
                                      onTap: () {
                                        if (_isNearbyOnly) {
                                          setState(() => _isNearbyOnly = false);
                                          _applyFilters();
                                        }
                                      },
                                    ),
                                    // Pill 2: À proximité (1 km)
                                    SelectPill(
                                      label: "À proximité (1 km)",
                                      icon: Icons.near_me_rounded,
                                      selected: _isNearbyOnly,
                                      onTap: _toggleNearbyFilter,
                                    ),
                                  ],
                                ),
                              ),

                              // Title section with count badge
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  18,
                                  20,
                                  6,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: SectionHeader(
                                        title: _isNearbyOnly
                                            ? "Pharmacies à moins de 1 km"
                                            : "Toutes les pharmacies",
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 11,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.mintTint,
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.pill,
                                        ),
                                      ),
                                      child: Text(
                                        "${_filteredPharmacies.length}",
                                        style: AppText.display(
                                          size: 14,
                                          color: AppColors.mintDeep,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // List view of pharmacies
                              Expanded(
                                child: _errorMessage != null
                                    ? SingleChildScrollView(
                                        padding: EdgeInsets.fromLTRB(
                                          20,
                                          8,
                                          20,
                                          dockInset + 20,
                                        ),
                                        child: SoftCard(
                                          tint: AppColors.coralTint,
                                          radius: AppRadii.md,
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const BlisterIcon(
                                                icon:
                                                    Icons.error_outline_rounded,
                                                tone: Tone.coral,
                                                size: 40,
                                                glow: false,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 2,
                                                      ),
                                                  child: Text(
                                                    _errorMessage!,
                                                    style: AppText.body(
                                                      size: 14,
                                                      weight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : _filteredPharmacies.isEmpty
                                    ? Center(
                                        child: SingleChildScrollView(
                                          padding: EdgeInsets.only(
                                            bottom: dockInset,
                                          ),
                                          child: EmptyState(
                                            icon: _isNearbyOnly
                                                ? Icons.near_me_disabled_rounded
                                                : Icons.search_off_rounded,
                                            tone: Tone.mint,
                                            title: _isNearbyOnly
                                                ? "Aucune pharmacie à proximité (moins de 1 km)."
                                                : "Aucune pharmacie trouvée.",
                                            message: _isNearbyOnly
                                                ? "Cliquer sur 'Toutes les pharmacies' pour voir la liste complète."
                                                : null,
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: EdgeInsets.fromLTRB(
                                          20,
                                          8,
                                          20,
                                          dockInset + 20,
                                        ),
                                        itemCount: _filteredPharmacies.length,
                                        itemBuilder: (context, index) {
                                          final pharmacy =
                                              _filteredPharmacies[index];
                                          double? dist;
                                          if (_locationPermissionGranted &&
                                              _currentPosition != null &&
                                              pharmacy.location.latitude !=
                                                  0.0 &&
                                              pharmacy.location.longitude !=
                                                  0.0) {
                                            dist = Geolocator.distanceBetween(
                                              _currentPosition!.latitude,
                                              _currentPosition!.longitude,
                                              pharmacy.location.latitude,
                                              pharmacy.location.longitude,
                                            );
                                          }

                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: SoftCard(
                                              onTap: () =>
                                                  _handleCheckIn(pharmacy),
                                              semanticLabel: pharmacy.name,
                                              radius: 24,
                                              padding: const EdgeInsets.all(14),
                                              child: Row(
                                                children: [
                                                  const TintIcon(
                                                    icon: Icons
                                                        .local_pharmacy_rounded,
                                                    tone: Tone.mint,
                                                    size: 48,
                                                  ),
                                                  const SizedBox(width: 14),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          pharmacy.name,
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              AppText.display(
                                                                size: 16.5,
                                                                height: 1.15,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          pharmacy
                                                                  .address
                                                                  .isNotEmpty
                                                              ? pharmacy.address
                                                              : "Pas d'adresse spécifiée",
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: AppText.body(
                                                            size: 13,
                                                            color: AppColors
                                                                .textMuted,
                                                          ),
                                                        ),
                                                        if (dist != null) ...[
                                                          const SizedBox(
                                                            height: 8,
                                                          ),
                                                          TonePill(
                                                            tone: Tone.mint,
                                                            icon: Icons
                                                                .directions_walk_rounded,
                                                            label: dist < 1000
                                                                ? "${dist.toStringAsFixed(0)} m"
                                                                : "${(dist / 1000).toStringAsFixed(1)} km",
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  // Check-in affordance
                                                  Container(
                                                    width: 42,
                                                    height: 42,
                                                    decoration:
                                                        const BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          gradient:
                                                              AppGradients.mint,
                                                        ),
                                                    child: const Icon(
                                                      Icons.login_rounded,
                                                      size: 20,
                                                      color: AppColors.ink,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGPSBlocker() {
    return Builder(
      builder: (context) => Center(
        child: SingleChildScrollView(
          // Keeps the message clear of the glass dock.
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
          child: EmptyState(
            icon: Icons.location_off_rounded,
            tone: Tone.coral,
            title: "Localisation GPS Requise",
            message:
                "L'accès à la position GPS de votre téléphone est requis pour utiliser le Check-in / Check-out.",
            actionLabel: "Autoriser / Réessayer",
            onAction: _initLocationAndFetchPharmacies,
          ),
        ),
      ),
    );
  }
}
