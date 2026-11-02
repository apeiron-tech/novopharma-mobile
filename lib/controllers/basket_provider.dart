import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novopharma/controllers/auth_provider.dart';
import 'package:novopharma/models/basket.dart';
import 'package:novopharma/models/basket_item.dart';
import 'package:novopharma/models/product.dart';
import 'package:novopharma/models/gift.dart';
import 'package:novopharma/models/gift_assignment.dart';
import 'package:novopharma/services/basket_service.dart';
import 'package:novopharma/services/gift_service.dart';
import 'package:novopharma/services/gift_eligibility_service.dart';

class BasketProvider with ChangeNotifier {
  final BasketService _basketService = BasketService();
  final GiftService _giftService = GiftService();

  AuthProvider? _auth;
  StreamSubscription<Basket?>? _basketSubscription;

  Basket? _currentBasket;
  Basket? get currentBasket => _currentBasket;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<GiftAssignment> _availableAssignments = [];
  final Map<String, Gift> _giftsMap = {};
  List<GiftThresholdEvaluation> _giftEvaluations = [];
  List<GiftThresholdEvaluation> get giftEvaluations => _giftEvaluations;

  List<GiftThresholdEvaluation> get eligibleUnlockedGifts =>
      _giftEvaluations.where((e) => e.isThresholdMet).toList();

  List<GiftThresholdEvaluation> get pendingThresholdGifts =>
      _giftEvaluations.where((e) => !e.isThresholdMet && e.neededQuantity > 0).toList();

  bool get hasOpenBasket => _currentBasket != null && _currentBasket!.items.isNotEmpty;
  int get totalItemsCount => _currentBasket?.itemsCount ?? 0;
  double get totalAmount => _currentBasket?.totalAmount ?? 0.0;
  double get totalPoints => _currentBasket?.totalPoints ?? 0.0;

  BasketProvider([AuthProvider? auth]) {
    if (auth != null) {
      update(auth);
    }
  }

  void update(AuthProvider auth) {
    _auth = auth;
    final userId = auth.userProfile?.uid ?? auth.firebaseUser?.uid;

    if (userId == null) {
      _basketSubscription?.cancel();
      _basketSubscription = null;
      _currentBasket = null;
      _giftEvaluations = [];
      notifyListeners();
      return;
    }

    if (_basketSubscription == null) {
      _initBasketSubscription(userId);
    }
  }

  void _initBasketSubscription(String userId) {
    _basketSubscription?.cancel();
    _basketSubscription = _basketService.streamOpenBasket(userId).listen((basket) {
      _currentBasket = basket;
      _refreshGiftEvaluations();
      notifyListeners();
    }, onError: (error) {
      log('[BasketProvider] Error in streamOpenBasket: $error');
    });
  }

  @override
  void dispose() {
    _basketSubscription?.cancel();
    super.dispose();
  }

  /// Refreshes and evaluates gifts for current basket items
  Future<void> _refreshGiftEvaluations() async {
    if (_currentBasket == null || _currentBasket!.items.isEmpty || _auth?.userProfile == null) {
      _giftEvaluations = [];
      notifyListeners();
      return;
    }

    try {
      final user = _auth!.userProfile!;
      final pharmacyId = _currentBasket!.pharmacyId;

      if (_availableAssignments.isEmpty) {
        if (user.role == 'Dermo-conseiller') {
          _availableAssignments = await _giftService.getAssignmentsForDermoOrPharmacy(
            pharmacyId: pharmacyId,
            dermoId: user.uid,
          );
        } else {
          _availableAssignments = await _giftService.getAssignmentsForPharmacy(pharmacyId);
        }

        final Set<String> giftIds = _availableAssignments.map((a) => a.giftId).toSet();
        for (final gId in giftIds) {
          if (!_giftsMap.containsKey(gId)) {
            final gift = await _giftService.getGiftById(gId);
            if (gift != null) {
              _giftsMap[gId] = gift;
            }
          }
        }
      }

      _giftEvaluations = GiftEligibilityService.evaluateBasket(
        assignments: _availableAssignments,
        giftsMap: _giftsMap,
        items: _currentBasket!.items,
      );
      notifyListeners();
    } catch (e) {
      log('[BasketProvider] Error evaluating gifts: $e');
    }
  }

  /// Adds a product to the basket. If no open basket exists, creates one.
  Future<bool> addProduct({
    required Product product,
    required int quantity,
    required double pointsEarned,
  }) async {
    final user = _auth?.userProfile;
    if (user == null) {
      _errorMessage = "Utilisateur non connecté.";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final activeVisitId = prefs.getString('active_visit_id');
      final activePharmacyId = prefs.getString('active_pharmacy_id') ?? user.pharmacyId;
      final activePharmacyName = prefs.getString('active_pharmacy_name') ?? user.pharmacy;
      final activePointOfSale = prefs.getString('active_point_of_sale') ?? user.pointOfSale;

      Basket basket;
      if (_currentBasket == null) {
        basket = await _basketService.createOpenBasket(
          userId: user.uid,
          userName: user.name,
          userDisplayId: user.uid,
          userRole: user.role,
          visitId: activeVisitId,
          pharmacyId: activePharmacyId,
          pharmacyName: activePharmacyName,
          pointOfSale: activePointOfSale,
          pharmacyClientCategory: user.role == 'Dermo-conseiller'
              ? 'Dermo-conseiller'
              : user.pharmacyCategory,
        );
        _currentBasket = basket;
      } else {
        basket = _currentBasket!;
      }

      final items = List<BasketItem>.from(basket.items);
      final existingIndex = items.indexWhere((i) => i.productId == product.id);

      if (existingIndex >= 0) {
        final existingItem = items[existingIndex];
        final newQty = existingItem.quantity + quantity;
        final newPoints = (pointsEarned / (quantity > 0 ? quantity : 1)) * newQty;
        items[existingIndex] = existingItem.copyWith(
          quantity: newQty,
          lineTotal: product.price * newQty,
          pointsEarned: newPoints,
        );
      } else {
        items.add(BasketItem(
          productId: product.id,
          name: product.name,
          sku: product.sku,
          marque: product.marque,
          category: product.category,
          imageUrl: product.imageUrl,
          unitPrice: product.price,
          quantity: quantity,
          lineTotal: product.price * quantity,
          pointsEarned: pointsEarned,
        ));
      }

      await _basketService.updateBasketItems(basket.id, items);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      log('[BasketProvider] Error adding product: $e');
      _errorMessage = "Erreur lors de l'ajout au panier: $e";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Updates quantity of an existing item in the basket
  Future<void> updateItemQuantity(String productId, int newQuantity) async {
    if (_currentBasket == null) return;

    final items = List<BasketItem>.from(_currentBasket!.items);
    final index = items.indexWhere((i) => i.productId == productId);
    if (index < 0) return;

    if (newQuantity <= 0) {
      items.removeAt(index);
    } else {
      final item = items[index];
      final unitPoints = item.quantity > 0 ? (item.pointsEarned / item.quantity) : 0.0;
      items[index] = item.copyWith(
        quantity: newQuantity,
        lineTotal: item.unitPrice * newQuantity,
        pointsEarned: unitPoints * newQuantity,
      );
    }

    try {
      await _basketService.updateBasketItems(_currentBasket!.id, items);
    } catch (e) {
      log('[BasketProvider] Error updating quantity: $e');
      _errorMessage = "Erreur de mise à jour: $e";
      notifyListeners();
    }
  }

  /// Removes an item from the basket
  Future<void> removeItem(String productId) async {
    await updateItemQuantity(productId, 0);
  }

  /// Cancels the current open basket
  Future<bool> cancelBasket({String? reason}) async {
    if (_currentBasket == null) return true;

    _isLoading = true;
    notifyListeners();

    try {
      await _basketService.cancelBasket(_currentBasket!.id, reason: reason);
      _currentBasket = null;
      _giftEvaluations = [];
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      log('[BasketProvider] Error cancelling basket: $e');
      _errorMessage = "Erreur lors de l'annulation: $e";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clôture le panier
  Future<bool> closeBasket({
    String? selectedGiftId,
    String? selectedAssignmentId,
    int giftQuantity = 1,
    String? clientNom,
    String? clientPrenom,
    String? clientPhone,
  }) async {
    if (_currentBasket == null || _currentBasket!.items.isEmpty) {
      _errorMessage = "Le panier est vide.";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _basketService.closeBasket(
        basketId: _currentBasket!.id,
        selectedGiftId: selectedGiftId,
        selectedAssignmentId: selectedAssignmentId,
        giftQuantity: giftQuantity,
        clientNom: clientNom,
        clientPrenom: clientPrenom,
        clientPhone: clientPhone,
      );

      final success = res['success'] == true;
      if (success) {
        _currentBasket = null;
        _giftEvaluations = [];
      } else {
        _errorMessage = res['message'] ?? "Échec de clôture du panier.";
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      log('[BasketProvider] Error closing basket: $e');
      _errorMessage = "Erreur lors de la clôture: $e";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
