import 'package:flutter/material.dart';

class FabVisibilityProvider with ChangeNotifier {
  bool _isVisible = true;

  bool get isVisible => _isVisible;

  void showFab() {
    if (!_isVisible) {
      _isVisible = true;
      notifyListeners();
    }
  }

  void hideFab() {
    if (_isVisible) {
      _isVisible = false;
      notifyListeners();
    }
  }
}
