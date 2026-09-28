import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:novopharma/models/product.dart';
import 'package:novopharma/models/stock_models.dart';
import 'package:novopharma/theme.dart';

class ExpirationDialog extends StatefulWidget {
  final Product product;
  final ProductStockItem? initialStockItem;
  final Function(ProductStockItem?) onSave;

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
  final _lotQuantityController = TextEditingController(text: "1");
  late bool _respectsPrice;
  final _sellingPriceController = TextEditingController();
  DateTime? _selectedDate;
  late bool _isPriceOnly;

  @override
  void initState() {
    super.initState();
    _expirations = widget.initialStockItem != null
        ? List<StockExpiration>.from(widget.initialStockItem!.expirations)
        : [];

    final initialStock = widget.initialStockItem;
    _isPriceOnly =
        initialStock?.isPriceOnly ??
        (initialStock != null && initialStock.totalQuantity == null);

    final initialQty = initialStock?.totalQuantity;
    _globalQuantityController.text = (initialQty != null && initialQty > 0)
        ? initialQty.toString()
        : '';

    _respectsPrice = initialStock?.respectsPrice ?? true;
    final initialSellingPrice = initialStock?.sellingPrice;
    _sellingPriceController.text = initialSellingPrice != null
        ? initialSellingPrice.toStringAsFixed(2)
        : '';
  }

  @override
  void dispose() {
    _globalQuantityController.dispose();
    _lotQuantityController.dispose();
    _sellingPriceController.dispose();
    super.dispose();
  }

  int get _sumOfLots =>
      _expirations.fold<int>(0, (sum, exp) => sum + exp.quantity);

  void _adjustQuantity(int delta) {
    int current = int.tryParse(_globalQuantityController.text) ?? 0;
    int next = current + delta;
    if (next < _sumOfLots) next = _sumOfLots;
    if (next < 0) next = 0;
    setState(() {
      _globalQuantityController.text = next > 0 ? next.toString() : '';
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate ?? DateTime.now().add(const Duration(days: 365)),
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
        const SnackBar(
          content: Text("Veuillez choisir une date d'expiration."),
          backgroundColor: LightModeColors.lightError,
        ),
      );
      return;
    }
    final int qty = int.tryParse(_lotQuantityController.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez entrer une quantité valide (> 0)."),
          backgroundColor: LightModeColors.lightError,
        ),
      );
      return;
    }

    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);

    setState(() {
      final existingIndex = _expirations.indexWhere(
        (e) => e.expirationDate == formattedDate,
      );
      if (existingIndex >= 0) {
        final existing = _expirations[existingIndex];
        _expirations[existingIndex] = StockExpiration(
          expirationDate: formattedDate,
          quantity: existing.quantity + qty,
        );
      } else {
        _expirations.add(
          StockExpiration(expirationDate: formattedDate, quantity: qty),
        );
      }

      _expirations.sort((a, b) => a.expirationDate.compareTo(b.expirationDate));

      _selectedDate = null;
      _lotQuantityController.text = "1";

      final sum = _sumOfLots;
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

  void _saveAndClose() {
    final String qtyText = _globalQuantityController.text.trim();
    final bool isSellingPriceEntered =
        !_respectsPrice || _sellingPriceController.text.trim().isNotEmpty;
    final bool shouldSavePriceOnly =
        _isPriceOnly ||
        (qtyText.isEmpty && _expirations.isEmpty && isSellingPriceEntered);

    if (!shouldSavePriceOnly && qtyText.isEmpty && _expirations.isEmpty) {
      widget.onSave(null);
      Navigator.pop(context);
      return;
    }

    double? sellingPrice;
    double? priceDifference;

    if (!_respectsPrice) {
      sellingPrice = double.tryParse(_sellingPriceController.text.trim());
      if (sellingPrice == null || sellingPrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Veuillez saisir un prix de vente réel valide (> 0).",
            ),
            backgroundColor: LightModeColors.lightError,
          ),
        );
        return;
      }
      priceDifference = sellingPrice - widget.product.price;
    } else {
      sellingPrice = widget.product.price;
      priceDifference = 0.0;
    }

    if (shouldSavePriceOnly) {
      final item = ProductStockItem(
        productId: widget.product.id,
        productName: widget.product.name,
        totalQuantity: null,
        expirations: [],
        respectsPrice: _respectsPrice,
        sellingPrice: sellingPrice,
        priceDifference: priceDifference,
        recommendedPrice: widget.product.price,
        isPriceOnly: true,
      );
      widget.onSave(item);
      Navigator.pop(context);
      return;
    }

    final int totalQty = int.tryParse(qtyText) ?? 0;
    final sum = _sumOfLots;
    if (totalQty < sum) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "La quantité globale ($totalQty) doit être supérieure ou égale à la somme des lots ($sum unités).",
          ),
          backgroundColor: LightModeColors.lightError,
        ),
      );
      return;
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
      isPriceOnly: false,
    );

    widget.onSave(item);
    Navigator.pop(context);
  }

  Widget _buildQuickChip(
    String label,
    VoidCallback onTap, {
    bool isDanger = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDanger
              ? const Color(0xFFFEE2E2)
              : LightModeColors.novoPharmaLightGray,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDanger
                ? const Color(0xFFFCA5A5)
                : LightModeColors.lightOutlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDanger
                ? LightModeColors.lightError
                : LightModeColors.novoPharmaBlue,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double? parsedSellingPrice = double.tryParse(
      _sellingPriceController.text.trim(),
    );
    final double? livePriceDiff =
        (parsedSellingPrice != null && !_respectsPrice)
        ? (parsedSellingPrice - widget.product.price)
        : null;

    final int currentQty = int.tryParse(_globalQuantityController.text) ?? 0;
    final int sumOfLots = _sumOfLots;
    final bool hasLots = _expirations.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      elevation: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          color: Colors.white,
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Product Details & Close Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: LightModeColors.novoPharmaLightGray,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: LightModeColors.lightOutlineVariant,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: widget.product.imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: widget.product.imageUrl,
                                    fit: BoxFit.contain,
                                    placeholder: (_, __) => const Center(
                                      child: SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.medication_liquid_rounded,
                                      size: 22,
                                      color: LightModeColors.novoPharmaBlue,
                                    ),
                                  )
                                : const Icon(
                                    Icons.medication_liquid_rounded,
                                    size: 22,
                                    color: LightModeColors.novoPharmaBlue,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (widget.product.marque.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            LightModeColors.novoPharmaLightBlue,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        widget.product.marque,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: LightModeColors.novoPharmaBlue,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    "SKU: ${widget.product.sku}",
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: LightModeColors.novoPharmaGray,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 22,
                            color: LightModeColors.novoPharmaGray,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 18,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Mode Selector: Segmented Pill Control
                    Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: BoxDecoration(
                        color: LightModeColors.novoPharmaLightGray,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _isPriceOnly = false),
                              borderRadius: BorderRadius.circular(11),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: !_isPriceOnly
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(11),
                                  boxShadow: !_isPriceOnly
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1.5),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_rounded,
                                      size: 15,
                                      color: !_isPriceOnly
                                          ? LightModeColors.novoPharmaBlue
                                          : LightModeColors.novoPharmaGray,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Stock & Prix",
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: !_isPriceOnly
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        color: !_isPriceOnly
                                            ? LightModeColors.novoPharmaBlue
                                            : LightModeColors.novoPharmaGray,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _isPriceOnly = true),
                              borderRadius: BorderRadius.circular(11),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _isPriceOnly
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(11),
                                  boxShadow: _isPriceOnly
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1.5),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.sell_rounded,
                                      size: 15,
                                      color: _isPriceOnly
                                          ? LightModeColors.novoPharmaBlue
                                          : LightModeColors.novoPharmaGray,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Prix seul",
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: _isPriceOnly
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        color: _isPriceOnly
                                            ? LightModeColors.novoPharmaBlue
                                            : LightModeColors.novoPharmaGray,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Section: Quantité Globale (Only if !isPriceOnly)
                    if (!_isPriceOnly) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Quantité en stock",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: LightModeColors.dashboardTextPrimary,
                            ),
                          ),
                          if (hasLots)
                            Text(
                              "Min. $sumOfLots (lots)",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: LightModeColors.novoPharmaBlue,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Modern Stepper with Large Buttons (Compact & Centered)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: LightModeColors.novoPharmaLightGray,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: LightModeColors.lightOutlineVariant,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                elevation: 0,
                                child: InkWell(
                                  onTap: () => _adjustQuantity(-1),
                                  borderRadius: BorderRadius.circular(12),
                                  child: const SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Icon(
                                      Icons.remove_rounded,
                                      size: 22,
                                      color:
                                          LightModeColors.dashboardTextPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 180,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: LightModeColors.lightOutlineVariant,
                                  ),
                                ),
                                child: Center(
                                  child: TextField(
                                    controller: _globalQuantityController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          LightModeColors.dashboardTextPrimary,
                                    ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      hintText: "0",
                                      hintStyle: TextStyle(
                                        color: LightModeColors.novoPharmaGray,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Material(
                                color: LightModeColors.novoPharmaBlue,
                                borderRadius: BorderRadius.circular(12),
                                elevation: 0,
                                child: InkWell(
                                  onTap: () => _adjustQuantity(1),
                                  borderRadius: BorderRadius.circular(12),
                                  child: const SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Icon(
                                      Icons.add_rounded,
                                      size: 22,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Quick Chips (+1, +5, +10, etc.)
                      Center(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildQuickChip("+1", () => _adjustQuantity(1)),
                            _buildQuickChip("+5", () => _adjustQuantity(5)),
                            _buildQuickChip("+10", () => _adjustQuantity(10)),
                            _buildQuickChip("+20", () => _adjustQuantity(20)),
                            if (currentQty > 0)
                              _buildQuickChip("Vider", () {
                                setState(() {
                                  _globalQuantityController.text = sumOfLots > 0
                                      ? sumOfLots.toString()
                                      : "";
                                });
                              }, isDanger: true),
                          ],
                        ),
                      ),

                      if (hasLots && currentQty > sumOfLots) ...[
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            "Dont ${currentQty - sumOfLots} unité(s) sans lot spécifique.",
                            style: const TextStyle(
                              fontSize: 11,
                              color: LightModeColors.novoPharmaGray,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),
                    ],

                    // Section: Prix de Vente & Conformité
                    const Text(
                      "Prix de vente en officine",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: LightModeColors.dashboardTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Interactive Choice Cards
                    Row(
                      children: [
                        // Choice 1: Prix conseillé respecté
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _respectsPrice = true),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _respectsPrice
                                    ? const Color(0xFFF0FDF4)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _respectsPrice
                                      ? const Color(0xFF10B981)
                                      : LightModeColors.lightOutlineVariant,
                                  width: _respectsPrice ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _respectsPrice
                                            ? Icons.check_circle_rounded
                                            : Icons
                                                  .radio_button_unchecked_rounded,
                                        size: 15,
                                        color: _respectsPrice
                                            ? const Color(0xFF10B981)
                                            : LightModeColors.novoPharmaGray,
                                      ),
                                      const SizedBox(width: 5),
                                      const Text(
                                        "Conseillé",
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "${widget.product.price.toStringAsFixed(2)} DT",
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: _respectsPrice
                                          ? const Color(0xFF047857)
                                          : LightModeColors
                                                .dashboardTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Choice 2: Prix différent
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _respectsPrice = false),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: !_respectsPrice
                                    ? const Color(0xFFFFFBEB)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: !_respectsPrice
                                      ? const Color(0xFFF59E0B)
                                      : LightModeColors.lightOutlineVariant,
                                  width: !_respectsPrice ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        !_respectsPrice
                                            ? Icons.edit_note_rounded
                                            : Icons
                                                  .radio_button_unchecked_rounded,
                                        size: 16,
                                        color: !_respectsPrice
                                            ? const Color(0xFFF59E0B)
                                            : LightModeColors.novoPharmaGray,
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        "Différent",
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    (!_respectsPrice &&
                                            _sellingPriceController.text
                                                .trim()
                                                .isNotEmpty)
                                        ? "${_sellingPriceController.text.trim()} DT"
                                        : "Autre prix",
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: !_respectsPrice
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: !_respectsPrice
                                          ? const Color(0xFFB45309)
                                          : LightModeColors.novoPharmaGray,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Custom Price Input & Difference Badge (Shown when !respectsPrice)
                    if (!_respectsPrice) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFDF5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Prix réel constaté",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: LightModeColors.dashboardTextPrimary,
                                  ),
                                ),
                                if (livePriceDiff != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: livePriceDiff > 0
                                          ? const Color(0xFFFEE2E2)
                                          : const Color(0xFFE0E7FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      livePriceDiff > 0
                                          ? "+${livePriceDiff.toStringAsFixed(2)} DT"
                                          : "${livePriceDiff.toStringAsFixed(2)} DT",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: livePriceDiff > 0
                                            ? LightModeColors.lightError
                                            : LightModeColors.novoPharmaBlue,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _sellingPriceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                hintText: "Ex: 28.50",
                                suffixText: "DT",
                                suffixStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: LightModeColors.novoPharmaBlue,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFCD34D),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFCD34D),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFF59E0B),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Section: Lots d'Expiration (Only if !isPriceOnly)
                    if (!_isPriceOnly) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: LightModeColors.novoPharmaLightGray,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: LightModeColors.lightOutlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_month_rounded,
                                      size: 15,
                                      color: LightModeColors.novoPharmaBlue,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      "Lots périssables",
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: LightModeColors
                                            .dashboardTextPrimary,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      "(Optionnel)",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: LightModeColors.novoPharmaGray,
                                      ),
                                    ),
                                  ],
                                ),
                                if (hasLots)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          LightModeColors.novoPharmaLightBlue,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "${_expirations.length} lot(s)",
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: LightModeColors.novoPharmaBlue,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Add Lot Row: Date + Qty + Add Button
                            Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: InkWell(
                                    onTap: () => _selectDate(context),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      height: 40,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: LightModeColors
                                              .lightOutlineVariant,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.event_available_rounded,
                                            size: 15,
                                            color:
                                                LightModeColors.novoPharmaBlue,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              _selectedDate == null
                                                  ? "Date d'exp."
                                                  : DateFormat(
                                                      'dd/MM/yyyy',
                                                    ).format(_selectedDate!),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight:
                                                    _selectedDate != null
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                color: _selectedDate == null
                                                    ? LightModeColors
                                                          .novoPharmaGray
                                                    : LightModeColors
                                                          .dashboardTextPrimary,
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
                                Expanded(
                                  flex: 3,
                                  child: SizedBox(
                                    height: 40,
                                    child: TextField(
                                      controller: _lotQuantityController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: "Qté",
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 10,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: LightModeColors
                                                .lightOutlineVariant,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: LightModeColors
                                                .lightOutlineVariant,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color:
                                                LightModeColors.novoPharmaBlue,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 40,
                                  child: ElevatedButton(
                                    onPressed: _addLot,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          LightModeColors.novoPharmaBlue,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.add_rounded,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Existing Lots List
                            if (hasLots) ...[
                              const SizedBox(height: 10),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 140,
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: _expirations.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 6),
                                  itemBuilder: (context, index) {
                                    final item = _expirations[index];
                                    final parsedDate = DateTime.tryParse(
                                      item.expirationDate,
                                    );
                                    final displayDate = parsedDate != null
                                        ? DateFormat(
                                            'dd/MM/yyyy',
                                          ).format(parsedDate)
                                        : item.expirationDate;

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: LightModeColors
                                              .lightOutlineVariant,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.access_time_rounded,
                                                size: 14,
                                                color: LightModeColors
                                                    .novoPharmaGray,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                displayDate,
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: LightModeColors
                                                      .dashboardTextPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: LightModeColors
                                                      .novoPharmaLightBlue,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  "${item.quantity} pcs",
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: LightModeColors
                                                        .novoPharmaBlue,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 17,
                                                  color: LightModeColors
                                                      .lightError,
                                                ),
                                                onPressed: () =>
                                                    _removeLot(index),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
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
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    // Dialog Action Buttons
                    Row(
                      children: [
                        if (widget.initialStockItem != null)
                          TextButton.icon(
                            onPressed: () {
                              widget.onSave(null);
                              Navigator.pop(context);
                            },
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: LightModeColors.lightError,
                            ),
                            label: const Text(
                              "Effacer",
                              style: TextStyle(
                                color: LightModeColors.lightError,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                          )
                        else
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "Annuler",
                              style: TextStyle(
                                color: LightModeColors.novoPharmaGray,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _saveAndClose,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LightModeColors.novoPharmaBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_rounded, size: 18),
                              SizedBox(width: 6),
                              Text(
                                "Valider",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
