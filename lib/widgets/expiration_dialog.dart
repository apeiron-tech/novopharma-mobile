import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:novopharma/models/product.dart';
import 'package:novopharma/models/stock_models.dart';
import 'package:novopharma/theme.dart';

class ExpirationDialog extends StatefulWidget {
  final Product product;
  final ProductStockItem? initialStockItem;
  final Function(ProductStockItem) onSave;

  const ExpirationDialog({
    super.key,
    required this.product,
    required this.initialStockItem,
    required this.onSave,
  });

  @override
  State<ExpirationDialog> createState() => _ExpirationDialogState();
}

class _ExpirationDialogState extends State<ExpirationDialog> {
  late List<StockExpiration> _expirations;
  final _globalQuantityController = TextEditingController();
  final _lotQuantityController = TextEditingController();
  late bool _respectsPrice;
  final _sellingPriceController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _expirations = widget.initialStockItem != null
        ? List<StockExpiration>.from(widget.initialStockItem!.expirations)
        : [];
    
    // Set initial global quantity
    final initialQty = widget.initialStockItem?.totalQuantity ?? 0;
    _globalQuantityController.text = initialQty > 0 ? initialQty.toString() : '';

    // Set initial price details
    _respectsPrice = widget.initialStockItem?.respectsPrice ?? true;
    final initialSellingPrice = widget.initialStockItem?.sellingPrice;
    _sellingPriceController.text = initialSellingPrice != null ? initialSellingPrice.toString() : '';
  }

  @override
  void dispose() {
    _globalQuantityController.dispose();
    _lotQuantityController.dispose();
    _sellingPriceController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: LightModeColors.novoPharmaBlue,
              onPrimary: Colors.white,
              onSurface: LightModeColors.dashboardTextPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addLot() {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez sélectionner une date d'expiration")),
      );
      return;
    }
    final int qty = int.tryParse(_lotQuantityController.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez entrer une quantité de lot valide (> 0)")),
      );
      return;
    }

    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);

    setState(() {
      final existingIndex = _expirations.indexWhere((e) => e.expirationDate == formattedDate);
      if (existingIndex >= 0) {
        final existing = _expirations[existingIndex];
        _expirations[existingIndex] = StockExpiration(
          expirationDate: formattedDate,
          quantity: existing.quantity + qty,
        );
      } else {
        _expirations.add(StockExpiration(expirationDate: formattedDate, quantity: qty));
      }
      
      _expirations.sort((a, b) => a.expirationDate.compareTo(b.expirationDate));

      // Reset lot fields
      _selectedDate = null;
      _lotQuantityController.clear();
      
      // Update global quantity if it is less than the sum of all lots
      final sum = _expirations.fold(0, (sum, exp) => sum + exp.quantity);
      final currentGlobal = int.tryParse(_globalQuantityController.text) ?? 0;
      if (currentGlobal < sum) {
        _globalQuantityController.text = sum.toString();
      }
    });
  }

  void _removeLot(int index) {
    setState(() {
      _expirations.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasLots = _expirations.isNotEmpty;
    final int sumOfLots = _expirations.fold(0, (sum, exp) => sum + exp.quantity);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 10,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Header with Image
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: LightModeColors.novoPharmaLightGray,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: LightModeColors.lightOutlineVariant),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: widget.product.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: widget.product.imageUrl,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const Center(
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.image_not_supported_outlined,
                                size: 18,
                                color: LightModeColors.novoPharmaGray,
                              ),
                            )
                          : const Icon(
                              Icons.image_not_supported_outlined,
                              size: 18,
                              color: LightModeColors.novoPharmaGray,
                            ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: LightModeColors.dashboardTextPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "SKU: ${widget.product.sku}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: LightModeColors.novoPharmaGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              
              // Global Quantity Input (Direct entry)
              const Text(
                "Quantité globale",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: LightModeColors.dashboardTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _globalQuantityController,
                keyboardType: TextInputType.number,
                enabled: true, // Always enabled
                decoration: InputDecoration(
                  hintText: "Saisir la quantité totale",
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    borderSide: const BorderSide(color: LightModeColors.novoPharmaBlue, width: 1.5),
                  ),
                ),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              if (hasLots) ...[
                const SizedBox(height: 4),
                Text(
                  "Doit être supérieure ou égale à la somme des lots ($sumOfLots unités). Le reste sera stocké sans date.",
                  style: const TextStyle(color: LightModeColors.novoPharmaGray, fontSize: 11),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Respecte le prix recommandé",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: LightModeColors.dashboardTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Prix recommandé: ${widget.product.price.toStringAsFixed(2)} DT",
                          style: const TextStyle(
                            fontSize: 11,
                            color: LightModeColors.novoPharmaGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _respectsPrice,
                    activeThumbColor: LightModeColors.novoPharmaBlue,
                    onChanged: (val) {
                      setState(() {
                        _respectsPrice = val;
                      });
                    },
                  ),
                ],
              ),
              if (!_respectsPrice) ...[
                const SizedBox(height: 12),
                const Text(
                  "Prix de vente réel (DT)",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: LightModeColors.dashboardTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _sellingPriceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: "Saisir le prix de vente en pharmacie",
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      borderSide: const BorderSide(color: LightModeColors.novoPharmaBlue, width: 1.5),
                    ),
                  ),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
              const Divider(height: 24),

              // Add Lot Section (Optional)
              const Text(
                "Lots d'expiration (Optionnel)",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: LightModeColors.dashboardTextPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: LightModeColors.novoPharmaLightGray,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: LightModeColors.lightOutlineVariant),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 14, color: LightModeColors.novoPharmaBlue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedDate == null
                                    ? "Date d'exp."
                                    : DateFormat('dd/MM/yyyy').format(_selectedDate!),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedDate != null ? FontWeight.bold : FontWeight.normal,
                                  color: _selectedDate == null
                                      ? LightModeColors.novoPharmaGray
                                      : LightModeColors.dashboardTextPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    height: 42,
                    child: TextField(
                      controller: _lotQuantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: "Qté",
                        filled: true,
                        fillColor: LightModeColors.novoPharmaLightGray,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          borderSide: const BorderSide(color: LightModeColors.novoPharmaBlue, width: 1.5),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: _addLot,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LightModeColors.novoPharmaBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: const Icon(Icons.add, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Lots Saisis header
              if (hasLots) ...[
                const Text(
                  "Lots saisis",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: LightModeColors.dashboardTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _expirations.length,
                    itemBuilder: (context, index) {
                      final item = _expirations[index];
                      final parsedDate = DateTime.tryParse(item.expirationDate);
                      final displayDate = parsedDate != null
                          ? DateFormat('dd/MM/yyyy').format(parsedDate)
                          : item.expirationDate;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: LightModeColors.lightOutlineVariant),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.history_toggle_off_rounded, size: 16, color: LightModeColors.novoPharmaGray),
                                const SizedBox(width: 8),
                                Text(
                                  displayDate,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: LightModeColors.dashboardTextPrimary),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: LightModeColors.novoPharmaLightBlue,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "${item.quantity} unités",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: LightModeColors.novoPharmaBlue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: LightModeColors.lightError, size: 18),
                                  onPressed: () => _removeLot(index),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const Divider(height: 28),
              
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Annuler", style: TextStyle(color: LightModeColors.novoPharmaGray, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final int totalQty = int.tryParse(_globalQuantityController.text) ?? 0;
                      
                      if (totalQty < sumOfLots) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "La quantité globale ($totalQty) doit être supérieure ou égale à la somme des lots ($sumOfLots unités).",
                            ),
                            backgroundColor: LightModeColors.lightError,
                          ),
                        );
                        return;
                      }

                      double? sellingPrice;
                      double? priceDifference;
                      if (!_respectsPrice) {
                        sellingPrice = double.tryParse(_sellingPriceController.text);
                        if (sellingPrice == null || sellingPrice <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Veuillez saisir un prix de vente valide."),
                              backgroundColor: LightModeColors.lightError,
                            ),
                          );
                          return;
                        }
                        priceDifference = sellingPrice - widget.product.price;
                      } else {
                        priceDifference = 0.0;
                      }

                      final item = ProductStockItem(
                        productId: widget.product.id,
                        productName: widget.product.name,
                        totalQuantity: totalQty,
                        expirations: _expirations,
                        respectsPrice: _respectsPrice,
                        sellingPrice: sellingPrice,
                        priceDifference: priceDifference,
                        recommendedPrice: widget.product.price,
                      );
                      
                      widget.onSave(item);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LightModeColors.novoPharmaBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    child: const Text("Enregistrer", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
