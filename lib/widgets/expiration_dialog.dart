import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:novopharma/models/product.dart';
import 'package:novopharma/models/stock_models.dart';
import 'package:novopharma/design/design.dart';

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
              primary: AppColors.indigo,
              onPrimary: Colors.white,
              onSurface: AppColors.text,
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
          backgroundColor: AppColors.coralDeep,
        ),
      );
      return;
    }
    final int qty = int.tryParse(_lotQuantityController.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez entrer une quantité valide (> 0)."),
          backgroundColor: AppColors.coralDeep,
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
            backgroundColor: AppColors.coralDeep,
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
          backgroundColor: AppColors.coralDeep,
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
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDanger ? AppColors.coralTint : AppColors.indigoTint,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          label,
          style: AppText.label(
            size: 12.5,
            weight: FontWeight.w700,
            color: isDanger ? AppColors.coralDeep : AppColors.indigoDeep,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  /// A section's heading inside the dialog.
  Widget _sectionTitle(String text) {
    return Text(text, style: AppText.display(size: 15.5));
  }

  /// A small count or amount beside a heading.
  Widget _miniPill(String text, {Tone tone = Tone.indigo}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.tint,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        text,
        style: AppText.display(size: 12, color: tone.deep, letterSpacing: 0),
      ),
    );
  }

  /// The inset panels the form is grouped into. Tinted, never blurred: the
  /// dialog behind them is already frosted.
  BoxDecoration _panelDecoration({Color tint = Colors.white, Color? border}) {
    return BoxDecoration(
      color: tint.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(AppRadii.md),
      border: Border.all(color: border ?? Colors.white),
    );
  }

  /// A square-ish control with a full-size tap target (stepper, add lot).
  Widget _squareButton({
    required IconData icon,
    required VoidCallback onTap,
    required String label,
    bool filled = false,
  }) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.9,
      semanticLabel: label,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: filled ? AppGradients.indigo : null,
          color: filled ? null : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: filled ? null : Border.all(color: AppColors.line),
          boxShadow: filled
              ? AppShadows.glow(AppColors.indigo, strength: 0.26)
              : null,
        ),
        child: Icon(
          icon,
          size: 22,
          color: filled ? Colors.white : AppColors.text,
        ),
      ),
    );
  }

  /// The dialog's text inputs: white wells with a soft outline that turns to
  /// [accent] on focus.
  InputDecoration _fieldDecoration({
    String? hintText,
    String? suffixText,
    Color accent = AppColors.indigo,
    Color outline = AppColors.line,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 12,
    ),
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppText.body(size: 15, color: AppColors.textFaint),
      suffixText: suffixText,
      suffixStyle: AppText.label(
        size: 14,
        weight: FontWeight.w700,
        color: AppColors.indigo,
      ),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: contentPadding,
      border: border(outline),
      enabledBorder: border(outline),
      focusedBorder: border(accent, 1.6),
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

    final closeLabel = MaterialLocalizations.of(context).closeButtonTooltip;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Glass(
          blur: Glass.frost,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Container(
                // A veil of white over the frost: this is a dense form, and
                // its figures have to stay crisp whatever shows through.
                color: Colors.white.withValues(alpha: 0.42),
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
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                            boxShadow: AppShadows.card,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                            child: widget.product.imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: widget.product.imageUrl,
                                    fit: BoxFit.contain,
                                    placeholder: (_, __) => const Center(
                                      child: CapsuleLoader(size: 22),
                                    ),
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.medication_liquid_rounded,
                                      size: 24,
                                      color: AppColors.indigo,
                                    ),
                                  )
                                : const Icon(
                                    Icons.medication_liquid_rounded,
                                    size: 24,
                                    color: AppColors.indigo,
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
                                style: AppText.display(size: 16.5, height: 1.2),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (widget.product.marque.isNotEmpty)
                                    TonePill(label: widget.product.marque),
                                  Text(
                                    "SKU: ${widget.product.sku}",
                                    style: AppText.label(
                                      size: 12,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: closeLabel,
                          child: Pressable(
                            onTap: () => Navigator.pop(context),
                            pressedScale: 0.9,
                            semanticLabel: closeLabel,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.ink.withValues(alpha: 0.07),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 22,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Mode Selector: Segmented Pill Control
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedTabs(
                        labels: const ["Stock & prix", "Prix seul"],
                        selectedIndex: _isPriceOnly ? 1 : 0,
                        onChanged: (index) => index == 0
                            ? setState(() => _isPriceOnly = false)
                            : setState(() => _isPriceOnly = true),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Section: Quantité Globale (Only if !isPriceOnly)
                    if (!_isPriceOnly) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: _sectionTitle("Quantité en stock")),
                          if (hasLots) _miniPill("Min. $sumOfLots (lots)"),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Stepper with large buttons
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: _panelDecoration(),
                        child: Row(
                          children: [
                            _squareButton(
                              icon: Icons.remove_rounded,
                              label: '-1',
                              onTap: () => _adjustQuantity(-1),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.sm,
                                  ),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: TextField(
                                  controller: _globalQuantityController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  textAlign: TextAlign.center,
                                  style: AppText.display(size: 22),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: "0",
                                    hintStyle: AppText.display(
                                      size: 22,
                                      weight: FontWeight.w500,
                                      color: AppColors.textFaint,
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _squareButton(
                              icon: Icons.add_rounded,
                              label: '+1',
                              filled: true,
                              onTap: () => _adjustQuantity(1),
                            ),
                          ],
                        ),
                      ),

                      if (hasLots && currentQty > sumOfLots) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 4),
                          child: Text(
                            "Dont ${currentQty - sumOfLots} unité(s) sans lot spécifique.",
                            style: AppText.label(
                              size: 12,
                              weight: FontWeight.w500,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                    ],

                    // Section: Prix de Vente & Conformité
                    _sectionTitle("Prix de vente en officine"),
                    const SizedBox(height: 10),

                    // Interactive Choice Cards
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Choice 1: Prix conseillé respecté
                          Expanded(
                            child: Pressable(
                              onTap: () =>
                                  setState(() => _respectsPrice = true),
                              semanticLabel: "Conseillé",
                              child: AnimatedContainer(
                                duration: AppMotion.fast,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _respectsPrice
                                      ? AppColors.mintTint
                                      : Colors.white.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.md,
                                  ),
                                  border: Border.all(
                                    color: _respectsPrice
                                        ? AppColors.mint
                                        : Colors.white,
                                    width: _respectsPrice ? 1.6 : 1,
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
                                          size: 18,
                                          color: _respectsPrice
                                              ? AppColors.mintDeep
                                              : AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            "Conseillé",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppText.label(
                                              size: 13,
                                              weight: FontWeight.w700,
                                              color: AppColors.text,
                                              letterSpacing: 0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        "${widget.product.price.toStringAsFixed(2)} DT",
                                        style: AppText.display(
                                          size: 19,
                                          color: _respectsPrice
                                              ? AppColors.mintDeep
                                              : AppColors.text,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Choice 2: Prix différent
                          Expanded(
                            child: Pressable(
                              onTap: () =>
                                  setState(() => _respectsPrice = false),
                              semanticLabel: "Différent",
                              child: AnimatedContainer(
                                duration: AppMotion.fast,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: !_respectsPrice
                                      ? AppColors.amberTint
                                      : Colors.white.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.md,
                                  ),
                                  border: Border.all(
                                    color: !_respectsPrice
                                        ? AppColors.amber
                                        : Colors.white,
                                    width: !_respectsPrice ? 1.6 : 1,
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
                                          size: 18,
                                          color: !_respectsPrice
                                              ? AppColors.amberDeep
                                              : AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            "Différent",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppText.label(
                                              size: 13,
                                              weight: FontWeight.w700,
                                              color: AppColors.text,
                                              letterSpacing: 0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      (!_respectsPrice &&
                                              _sellingPriceController.text
                                                  .trim()
                                                  .isNotEmpty)
                                          ? "${_sellingPriceController.text.trim()} DT"
                                          : "Autre prix",
                                      maxLines: 1,
                                      style: AppText.display(
                                        size: 19,
                                        weight: !_respectsPrice
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: !_respectsPrice
                                            ? AppColors.amberDeep
                                            : AppColors.textMuted,
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
                    ),

                    // Custom Price Input & Difference Badge (Shown when !respectsPrice)
                    if (!_respectsPrice) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: _panelDecoration(
                          tint: AppColors.amberTint,
                          border: AppColors.amber.withValues(alpha: 0.45),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    "Prix réel constaté",
                                    style: AppText.label(
                                      size: 13,
                                      weight: FontWeight.w700,
                                      color: AppColors.text,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                                if (livePriceDiff != null)
                                  _miniPill(
                                    livePriceDiff > 0
                                        ? "+${livePriceDiff.toStringAsFixed(2)} DT"
                                        : "${livePriceDiff.toStringAsFixed(2)} DT",
                                    tone: livePriceDiff > 0
                                        ? Tone.coral
                                        : Tone.indigo,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _sellingPriceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: AppText.display(size: 19),
                              cursorColor: AppColors.amberDeep,
                              decoration: _fieldDecoration(
                                hintText: "Ex: 28.50",
                                suffixText: "DT",
                                accent: AppColors.amber,
                                outline: AppColors.amber.withValues(alpha: 0.55),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Section: Lots d'Expiration (Only if !isPriceOnly)
                    if (!_isPriceOnly) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: _panelDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  size: 18,
                                  color: AppColors.indigo,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      text: "Lots périssables",
                                      style: AppText.display(size: 15.5),
                                      children: [
                                        const TextSpan(text: "  "),
                                        TextSpan(
                                          text: "(Optionnel)",
                                          style: AppText.label(
                                            size: 12,
                                            weight: FontWeight.w500,
                                            letterSpacing: 0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (hasLots) ...[
                                  const SizedBox(width: 8),
                                  _miniPill("${_expirations.length} lot(s)"),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Add Lot Row: Date + Qty + Add Button
                            Row(
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Pressable(
                                    onTap: () => _selectDate(context),
                                    pressedScale: 0.97,
                                    child: Container(
                                      height: 46,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.sm,
                                        ),
                                        border: Border.all(
                                          color: AppColors.line,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.event_available_rounded,
                                            size: 18,
                                            color: AppColors.indigo,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            // Scales rather than truncates:
                                            // a date must read in full.
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                _selectedDate == null
                                                    ? "Date d'exp."
                                                    : DateFormat(
                                                        'dd/MM/yyyy',
                                                      ).format(_selectedDate!),
                                                style: _selectedDate != null
                                                    ? AppText.display(
                                                        size: 14.5,
                                                        letterSpacing: 0,
                                                      )
                                                    : AppText.body(
                                                        size: 14,
                                                        color:
                                                            AppColors.textMuted,
                                                      ),
                                                maxLines: 1,
                                              ),
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
                                    height: 46,
                                    child: TextField(
                                      controller: _lotQuantityController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: AppText.display(
                                        size: 16,
                                        letterSpacing: 0,
                                      ),
                                      decoration: _fieldDecoration(
                                        hintText: "Qté",
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 14,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _squareButton(
                                  icon: Icons.add_rounded,
                                  label: '+',
                                  filled: true,
                                  onTap: _addLot,
                                ),
                              ],
                            ),

                            // Existing Lots List
                            if (hasLots) ...[
                              const SizedBox(height: 12),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 140,
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
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
                                    // Presentation only: a lot whose date is
                                    // already behind us is shown in coral.
                                    final today = DateUtils.dateOnly(
                                      DateTime.now(),
                                    );
                                    final isExpired =
                                        parsedDate != null &&
                                        parsedDate.isBefore(today);

                                    return Container(
                                      padding: const EdgeInsets.only(left: 12),
                                      decoration: BoxDecoration(
                                        color: isExpired
                                            ? AppColors.coralTint
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.sm,
                                        ),
                                        border: Border.all(
                                          color: isExpired
                                              ? AppColors.coral.withValues(
                                                  alpha: 0.45,
                                                )
                                              : AppColors.line,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isExpired
                                                ? Icons.error_outline_rounded
                                                : Icons.access_time_rounded,
                                            size: 16,
                                            color: isExpired
                                                ? AppColors.coralDeep
                                                : AppColors.textMuted,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              displayDate,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppText.display(
                                                size: 14.5,
                                                letterSpacing: 0,
                                                color: isExpired
                                                    ? AppColors.coralDeep
                                                    : AppColors.text,
                                              ),
                                            ),
                                          ),
                                          _miniPill(
                                            "${item.quantity} pcs",
                                            tone: isExpired
                                                ? Tone.coral
                                                : Tone.indigo,
                                          ),
                                          Tooltip(
                                            message: MaterialLocalizations.of(
                                              context,
                                            ).deleteButtonTooltip,
                                            child: Pressable(
                                              onTap: () => _removeLot(index),
                                              pressedScale: 0.88,
                                              semanticLabel:
                                                  MaterialLocalizations.of(
                                                    context,
                                                  ).deleteButtonTooltip,
                                              child: const SizedBox.square(
                                                dimension: 44,
                                                child: Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 20,
                                                  color: AppColors.coralDeep,
                                                ),
                                              ),
                                            ),
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
                        Expanded(
                          flex: 2,
                          child: widget.initialStockItem != null
                              ? SecondaryButton(
                                  label: "Effacer",
                                  icon: Icons.delete_outline_rounded,
                                  tone: Tone.coral,
                                  onPressed: () {
                                    widget.onSave(null);
                                    Navigator.pop(context);
                                  },
                                )
                              : SecondaryButton(
                                  label: "Annuler",
                                  onPressed: () => Navigator.pop(context),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: PrimaryButton(
                            label: "Valider",
                            icon: Icons.check_rounded,
                            height: 52,
                            onPressed: _saveAndClose,
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
