import 'package:flutter/material.dart';
import 'package:novopharma/models/sale.dart';
import 'package:novopharma/services/sale_service.dart';

class SalesHistoryProvider with ChangeNotifier {
  final SaleService _saleService = SaleService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Sale> _salesHistory = [];
  List<Sale> get salesHistory => _salesHistory;

  String? _error;
  String? get error => _error;

  DateTime? _startDate;
  DateTime? get startDate => _startDate;

  DateTime? _endDate;
  DateTime? get endDate => _endDate;

  void setStartDate(DateTime date) {
    _startDate = date;
    notifyListeners();
  }

  void setEndDate(DateTime date) {
    _endDate = date;
    notifyListeners();
  }

  void clearFilters() {
    _startDate = null;
    _endDate = null;
    notifyListeners();
  }

  Future<void> fetchSalesHistory(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _salesHistory = await _saleService.getSalesHistory(
        userId,
        startDate: _startDate,
        endDate: _endDate,
      );
    } catch (e) {
      _error = "Failed to load sales history.";
      print('Error fetching sales history: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteSale(Sale sale) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _saleService.deleteSale(sale);
      _salesHistory.removeWhere((s) => s.id == sale.id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = "Failed to delete sale.";
      print('Error deleting sale: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSale(Sale oldSale, Sale newSale) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _saleService.updateSale(oldSale, newSale);
      final index = _salesHistory.indexWhere((s) => s.id == oldSale.id);
      if (index != -1) {
        _salesHistory[index] = newSale;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = "Failed to update sale.";
      print('Error updating sale: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
