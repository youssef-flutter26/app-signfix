import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_utils.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../payment/payment_screen.dart';
import '../../widgets/common.dart';
import '../../widgets/address_autocomplete_field.dart';

class SignageFontOption {
  const SignageFontOption({
    required this.name,
    required this.displayName,
    required this.category,
    required this.styleBuilder,
  });

  final String name;
  final String displayName;
  final String category;
  final TextStyle Function(double size, Color color, FontWeight weight)
      styleBuilder;
}

class SignageDesignerScreen extends StatefulWidget {
  const SignageDesignerScreen({
    super.key,
    required this.api,
    this.promotionBannerId = 'home_banner_3',
    this.onOrderSubmitted,
  });

  final ApiClient api;
  final String promotionBannerId;
  final VoidCallback? onOrderSubmitted;

  @override
  State<SignageDesignerScreen> createState() => _SignageDesignerScreenState();
}

class _SignageDesignerScreenState extends State<SignageDesignerScreen> {
  final _textCtrl = TextEditingController(text: 'SIGNFIX STUDIOS');
  final _addressCtrl = TextEditingController();
  final _addressFieldKey = GlobalKey<AddressAutocompleteFieldState>();
  StructuredAddress? _structuredAddress;

  // ── STRICT approved 5 fonts for Signage ───────────────────────────────────
  static final List<SignageFontOption> approvedFonts = [
    SignageFontOption(
      name: 'Montserrat',
      displayName: 'Montserrat (Modern Sans)',
      category: 'Geometric Bold',
      styleBuilder: (size, color, weight) => GoogleFonts.montserrat(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: 1.5,
      ),
    ),
    SignageFontOption(
      name: 'Bebas Neue',
      displayName: 'Bebas Neue (Headline)',
      category: 'Storefront All-Caps',
      styleBuilder: (size, color, weight) => GoogleFonts.bebasNeue(
        fontSize: size * 1.15,
        color: color,
        letterSpacing: 2.0,
      ),
    ),
    SignageFontOption(
      name: 'Playfair Display',
      displayName: 'Playfair (Luxury Serif)',
      category: 'Boutique & Luxury',
      styleBuilder: (size, color, weight) => GoogleFonts.playfairDisplay(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: 0.8,
      ),
    ),
    SignageFontOption(
      name: 'Outfit',
      displayName: 'Outfit (Architectural)',
      category: 'Contemporary Clean',
      styleBuilder: (size, color, weight) => GoogleFonts.outfit(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: 1.2,
      ),
    ),
    SignageFontOption(
      name: 'Oswald',
      displayName: 'Oswald (Commercial)',
      category: 'Industrial Retail',
      styleBuilder: (size, color, weight) => GoogleFonts.oswald(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: 1.5,
      ),
    ),
  ];

  late SignageFontOption _selectedFont;
  Color _textColor = AppColors.gold;
  String _textColorName = 'Gold';
  Color _glowColor = AppColors.goldLight;
  final TextAlign _alignment = TextAlign.center;

  // Backing Materials
  static const List<Map<String, dynamic>> _backings = [
    {
      'id': 'acrylic_black',
      'name': 'Glossy Black Acrylic',
      'rate': 950,
      'color': AppColors.navy,
      'texture': 'gloss'
    },
    {
      'id': 'acrylic_clear',
      'name': 'Clear Acrylic Backing',
      'rate': 850,
      'color': AppColors.white20,
      'texture': 'glass'
    },
    {
      'id': 'acp_brushed_gold',
      'name': 'Brushed Gold ACP',
      'rate': 1250,
      'color': AppColors.goldDark,
      'texture': 'metallic'
    },
    {
      'id': 'acp_silver',
      'name': 'Silver Aluminium Panel',
      'rate': 1100,
      'color': AppColors.softGray,
      'texture': 'metallic'
    },
    {
      'id': 'wood_grain',
      'name': 'Architectural Walnut Wood',
      'rate': 1350,
      'color': AppColors.navyDeep,
      'texture': 'wood'
    },
  ];
  Map<String, dynamic> _selectedBacking = _backings[0];

  // Wall background environments
  static const List<Map<String, dynamic>> _walls = [
    {'id': 'dark_brick', 'name': 'Exposed Dark Brick', 'bg': AppColors.navy},
    {'id': 'concrete', 'name': 'Industrial Concrete', 'bg': AppColors.charcoal},
    {'id': 'storefront', 'name': 'Modern Storefront', 'bg': AppColors.navyDeep},
    {'id': 'marble', 'name': 'Luxury Dark Marble', 'bg': AppColors.navy},
  ];
  final Map<String, dynamic> _selectedWall = _walls[0];

  // Dimensions
  double _widthFt = 3.0;
  double _heightFt = 1.5;
  final int _quantity = 1;
  Map<String, dynamic>? _serverQuote;
  bool _isCalculatingPrice = true;
  String? _pricingError;
  Timer? _priceDebounce;
  int _priceRequestGeneration = 0;

  // AI Design Generation State
  bool _isGeneratingAi = false;
  String? _aiGeneratedImageUrl;
  String? _aiPrompt;
  bool _aiConfirmed = false;
  String? _aiGenerationMessage;

  bool _submittingOrder = false;

  @override
  void initState() {
    super.initState();
    _selectedFont = approvedFonts[0];
    unawaited(_refreshServerQuote());
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _addressCtrl.dispose();
    _priceDebounce?.cancel();
    super.dispose();
  }

  double? get _calculatedPrice =>
      (_serverQuote?['estimatedPrice'] as num?)?.toDouble();

  String get _calculatorMaterial => switch (_selectedBacking['id']) {
        'acrylic_black' || 'acrylic_clear' => 'Acrylic',
        'acp_brushed_gold' => 'ACP',
        'acp_silver' => 'Aluminium',
        'wood_grain' => 'Other',
        _ => 'Acrylic',
      };

  Map<String, dynamic> get _calculatorInput => {
        'product': 'Acrylic Sign Board',
        'length': _widthFt,
        'width': _heightFt,
        'unit': 'ft',
        'quantity': _quantity,
        'material': _calculatorMaterial,
        'lighting': 'LED',
        'installation': true,
        'transportation': true,
      };

  Future<bool> _refreshServerQuote() async {
    final requestGeneration = ++_priceRequestGeneration;
    if (mounted) {
      setState(() {
        _isCalculatingPrice = true;
        _pricingError = null;
        _serverQuote = null;
      });
    }
    try {
      final quote = await widget.api.calculate(_calculatorInput);
      if (!mounted || requestGeneration != _priceRequestGeneration) {
        return false;
      }
      setState(() => _serverQuote = quote);
      return true;
    } catch (error) {
      if (mounted && requestGeneration == _priceRequestGeneration) {
        setState(() => _pricingError = error.toString());
      }
      return false;
    } finally {
      if (mounted && requestGeneration == _priceRequestGeneration) {
        setState(() => _isCalculatingPrice = false);
      }
    }
  }

  void _scheduleServerQuote() {
    _priceDebounce?.cancel();
    _priceRequestGeneration++;
    setState(() {
      _isCalculatingPrice = true;
      _pricingError = null;
      _serverQuote = null;
    });
    _priceDebounce = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_refreshServerQuote()),
    );
  }

  bool get _hasBannerMinimum =>
      requiresPromotionalOrderMinimum(widget.promotionBannerId);

  double get _minimumOrderShortfall =>
      _hasBannerMinimum ? orderMinimumShortfall(_calculatedPrice ?? 0) : 0;

  bool _validateDeliveryRegion() {
    final isValid =
        _addressFieldKey.currentState?.validateRequiredRegionFields() ?? false;
    if (!isValid && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Enter City, State and a valid 6-digit Pincode to continue.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return isValid;
  }

  Future<void> _generateAiDesign() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter signboard text first.'),
            backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() {
      _isGeneratingAi = true;
      _aiConfirmed = false;
      _aiGenerationMessage = '🎨 Generating 3D Signboard Concept... Please wait';
    });

    try {
      // Same AI chat route that already produces design images in the AI chat.
      // Plain color names are used because the AI ignores hex codes.
      final prompt =
          'Create a 3D LED signboard design with the name "$text". '
          'Follow these selections EXACTLY and do not change them: '
          'the letters and their LED glow must be $_textColorName in color '
          '(not gold unless the color is Gold); '
          'backing panel material: ${_selectedBacking['name']}; '
          'font style: ${_selectedFont.name} (${_selectedFont.category} lettering); '
          'sign size: ${_widthFt.toStringAsFixed(1)} ft wide by ${_heightFt.toStringAsFixed(1)} ft high. '
          'Show it as a photorealistic 3D sign mounted on a modern storefront facade. '
          'The letters must be spelled exactly "$text" and be $_textColorName.';
      final res = await widget.api.chat(prompt);
      String? imageUrl = (res['imageUrl'] ?? res['image'])?.toString();
      if (imageUrl == null || imageUrl.trim().isEmpty) {
        final match = RegExp(r'!\[[^\]]*\]\((https?://[^)\s]+)\)')
            .firstMatch(res['reply']?.toString() ?? '');
        imageUrl = match?.group(1);
      }
      if (imageUrl == null || imageUrl.trim().isEmpty) {
        throw const ApiException(
            'The AI did not return an image this time. Please try again.');
      }

      if (!mounted) return;
      setState(() {
        _aiGeneratedImageUrl = imageUrl;
        _aiPrompt = prompt;
        _aiGenerationMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiGenerationMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('AI Generation note: $e'),
            backgroundColor: AppColors.warning),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingAi = false);
    }
  }

  Future<void> _submitSignageOrder({bool retryAfterPriceChange = true}) async {
    final text = _textCtrl.text.trim();
    final address = _structuredAddress?.fullDisplayAddress.isNotEmpty == true
        ? _structuredAddress!.fullDisplayAddress
        : _addressCtrl.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter signboard text.'),
            backgroundColor: AppColors.danger),
      );
      return;
    }
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please provide delivery address.'),
            backgroundColor: AppColors.danger),
      );
      return;
    }
    if (!_validateDeliveryRegion()) return;
    if (_isCalculatingPrice || _calculatedPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Wait for the latest server price before submitting.')),
      );
      return;
    }
    if (_minimumOrderShortfall > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Minimum order is ${money(2500)}. Increase the sign size or add options worth ${money(_minimumOrderShortfall.ceil())} more.',
          ),
        ),
      );
      return;
    }

    final pricingInput = Map<String, dynamic>.from(_calculatorInput);
    final estimatedPrice = _calculatedPrice!;
    setState(() => _submittingOrder = true);
    try {
      final orderSpecs = {
        ...pricingInput,
        'category': 'Signage Design System',
        'signText': text,
        'signFont': _selectedFont.name,
        'signColor':
            '#${_textColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        'backingMaterial': _selectedBacking['name'],
        'backingId': _selectedBacking['id'],
        'wallStyle': _selectedWall['name'],
        'address': address,
        'city': _structuredAddress?.city.trim(),
        'state': _structuredAddress?.state.trim(),
        'pincode': _structuredAddress?.pincode.trim(),
        'deliveryAddress': _structuredAddress?.toMap(),
        'saveAddress': _structuredAddress?.saveToProfile ?? false,
        'estimatedPrice': estimatedPrice,
        'aiGeneratedImageUrl': _aiConfirmed ? _aiGeneratedImageUrl : null,
        'aiPrompt': _aiConfirmed ? _aiPrompt : null,
        'idempotencyKey':
            '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32).toRadixString(16)}',
        'promotionBannerId': widget.promotionBannerId,
      };

      final order = await widget.api.createOrder(orderSpecs);
      final orderNo = order['id']?.toString() ?? '';

      if (!mounted) return;
      setState(() => _submittingOrder = false);

      // Open Razorpay for the new order (server computes the payable amount).
      var paid = false;
      try {
        paid = await payForOrder(
          context,
          widget.api,
          orderNo: orderNo,
          amount: estimatedPrice,
          description: 'Signboard order $orderNo',
        );
      } catch (_) {
        paid = false;
      }
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.navyDark,
          icon: Icon(
              paid ? Icons.check_circle_rounded : Icons.schedule_rounded,
              color: paid ? AppColors.success : AppColors.gold,
              size: 48),
          title: Text(
              paid ? 'Payment Successful' : 'Order Saved - Payment Pending',
              style: const TextStyle(color: AppColors.white)),
          content: Text(
            'Order #$orderNo has been submitted successfully.\n${paid ? 'Your payment was received.' : 'Payment is not completed yet.'}\n\nSignboard: "$text"\nFont: ${_selectedFont.name}\nBacking: ${_selectedBacking['name']}\nSize: $_widthFt×$_heightFt ft\nTotal: ${money(_calculatedPrice)}\n\nEligible for ₹200 Cashback upon verified payment.',
            style: const TextStyle(color: AppColors.darkSecondary),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onOrderSubmitted?.call();
                Navigator.pop(context);
              },
              child: const Text('View in Orders'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (e is ApiException && e.statusCode == 409 && retryAfterPriceChange) {
        if (mounted) setState(() => _submittingOrder = false);
        final oldPrice = _calculatedPrice;
        final refreshed = await _refreshServerQuote();
        if (!mounted || !refreshed || _calculatedPrice == null) return;
        final accepted = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Price updated'),
                content: Text(
                  'The server price changed from ${money(oldPrice)} to ${money(_calculatedPrice)}. Confirm the new estimate to submit again.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Review later'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Confirm new price'),
                  ),
                ],
              ),
            ) ??
            false;
        if (accepted && mounted) {
          await _submitSignageOrder(retryAfterPriceChange: false);
        }
        return;
      }
      if (mounted) {
        setState(() => _submittingOrder = false);
        showAppError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewText = _textCtrl.text.isEmpty ? 'SIGNFIX' : _textCtrl.text;
    final serverArea = _serverQuote?['area'];
    final areaLabel = serverArea is num
        ? '${serverArea.toStringAsFixed(1)} ${_serverQuote?['areaUnit'] ?? 'sqft'}'
        : 'Area pending server quote';
    final backingColor = _selectedBacking['color'] as Color;
    final previewBackingColor = Color.alphaBlend(
      backingColor,
      _selectedWall['bg'] as Color,
    );
    final outlineColor =
        AppColors.signPreviewOutline(_textColor, previewBackingColor);
    final previewTextStyle =
        _selectedFont.styleBuilder(24, _textColor, FontWeight.w800);

    return Scaffold(
      backgroundColor: AppColors.softGray,
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        foregroundColor: AppColors.navy,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.gold),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Signage Design Studio',
                style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
            Text('Neon Adda 3D Workflow · Approved 5 Fonts',
                style: TextStyle(color: AppColors.midGray, fontSize: 11)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withValues(alpha: .45)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.savings_outlined,
                    color: AppColors.goldDark, size: 13),
                SizedBox(width: 4),
                Text('₹200 Cashback',
                    style: TextStyle(
                        color: AppColors.goldDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Live Wall & Signboard Preview Stage (Neon Adda style) ─────────
          Container(
            height: 230,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _selectedWall['bg'] as Color,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Backing plate representation
                Container(
                  width: 280,
                  height: 120,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: backingColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: .2),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _glowColor.withValues(alpha: .25),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (outlineColor != null)
                          Text(
                            previewText,
                            key: const ValueKey('sign-preview-outline'),
                            textAlign: _alignment,
                            style: previewTextStyle.copyWith(
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 2.5
                                ..color = outlineColor,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          previewText,
                          key: const ValueKey('sign-preview-text'),
                          textAlign: _alignment,
                          style: previewTextStyle.copyWith(
                            shadows: [
                              Shadow(
                                  color: _glowColor.withValues(alpha: .85),
                                  blurRadius: 10),
                              Shadow(
                                  color: _glowColor.withValues(alpha: .45),
                                  blurRadius: 20),
                            ],
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                // Dimensions overlay badge
                Positioned(
                  bottom: 12,
                  right: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: .6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_widthFt.toStringAsFixed(1)} × ${_heightFt.toStringAsFixed(1)} ft ($areaLabel)',
                      style: const TextStyle(
                          color: AppColors.darkSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                // Backing style badge
                Positioned(
                  top: 12,
                  left: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: .6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _selectedBacking['name'] as String,
                      style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Text Input ─────────────────────────────────────────────────────
          TextField(
            controller: _textCtrl,
            style: const TextStyle(
                color: AppColors.textBody,
                fontSize: 15,
                fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              labelText: 'Signboard Text (Brand Name or Words)',
              labelStyle: const TextStyle(fontSize: 12),
              hintText: 'Enter your business name or storefront text',
              prefixIcon:
                  const Icon(Icons.edit_note_rounded, color: AppColors.gold),
              suffixIcon: _textCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.midGray),
                      onPressed: () => setState(() => _textCtrl.clear()),
                    )
                  : null,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          // ── STRICT Approved Five Fonts Selection ────────────────────────────
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 6,
            spacing: 8,
            children: [
              const Text('Approved Five Fonts',
                  style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Strict Specification',
                    style: TextStyle(
                        color: AppColors.goldDark,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: approvedFonts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final font = approvedFonts[i];
              final isSelected = _selectedFont.name == font.name;

              return GestureDetector(
                onTap: () => setState(() => _selectedFont = font),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.gold : AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.goldDark
                          : AppColors.cardBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: isSelected ? AppColors.gold : AppColors.midGray,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(font.displayName,
                                style: const TextStyle(
                                    color: AppColors.navy,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                            Text(font.category,
                                style: const TextStyle(
                                    color: AppColors.midGray, fontSize: 10)),
                          ],
                        ),
                      ),
                      Text(
                        'Sample',
                        style: font.styleBuilder(
                            16,
                            isSelected ? AppColors.gold : AppColors.midGray,
                            FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Text Color & Glow Palette ──────────────────────────────────────
          const Text('Lettering & Illumination Color',
              style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _colorCircle(AppColors.gold, 'Gold', AppColors.goldLight),
              _colorCircle(AppColors.white, 'White', AppColors.midGray),
              _colorCircle(AppColors.navy, 'Navy', AppColors.navyDeep),
              _colorCircle(AppColors.navyDeep, 'Deep Blue', AppColors.navy),
              _colorCircle(AppColors.softGray, 'Soft Gray', AppColors.midGray),
            ],
          ),
          const SizedBox(height: 22),

          // ── Backing Material Selector ──────────────────────────────────────
          const Text('Signboard Backing Material',
              style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _backings.map((b) {
              final isSel = _selectedBacking['id'] == b['id'];
              return ChoiceChip(
                key: ValueKey('signage-backing-${b['id']}'),
                label: Text(b['name'] as String,
                    style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                selected: isSel,
                selectedColor: AppColors.gold,
                backgroundColor: AppColors.white,
                side: const BorderSide(color: AppColors.cardBorder),
                onSelected: (_) {
                  setState(() => _selectedBacking = b);
                  _scheduleServerQuote();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // ── Dimensions Selector ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 4,
                  spacing: 8,
                  children: [
                    const Text('Dimensions & Scale',
                        style: TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                    Text(
                        '${_widthFt.toStringAsFixed(1)} ft Width × ${_heightFt.toStringAsFixed(1)} ft Height',
                        style: const TextStyle(
                            color: AppColors.goldDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Width: ',
                        style:
                            TextStyle(color: AppColors.midGray, fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _widthFt,
                        min: 1.0,
                        max: 10.0,
                        divisions: 18,
                        activeColor: AppColors.gold,
                        onChanged: (v) {
                          setState(() => _widthFt = v);
                          _scheduleServerQuote();
                        },
                      ),
                    ),
                    Text('${_widthFt.toStringAsFixed(1)} ft',
                        style: const TextStyle(
                            color: AppColors.navy, fontSize: 12)),
                  ],
                ),
                Row(
                  children: [
                    const Text('Height: ',
                        style:
                            TextStyle(color: AppColors.midGray, fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _heightFt,
                        min: 0.5,
                        max: 5.0,
                        divisions: 18,
                        activeColor: AppColors.gold,
                        onChanged: (v) {
                          setState(() => _heightFt = v);
                          _scheduleServerQuote();
                        },
                      ),
                    ),
                    Text('${_heightFt.toStringAsFixed(1)} ft',
                        style: const TextStyle(
                            color: AppColors.navy, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Order & Create AI Button & Preview ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withValues(alpha: .4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppColors.gold, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Order & Create: AI Storefront Preview',
                          style: TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                    'Generate an actual photorealistic AI visualization of your custom sign installed on a storefront facade before final checkout.',
                    style: TextStyle(
                        color: AppColors.textBody, fontSize: 11, height: 1.3)),
                const SizedBox(height: 14),
                if (_aiGeneratedImageUrl != null) ...[
                  GestureDetector(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => Dialog(
                        backgroundColor: Colors.black,
                        insetPadding: EdgeInsets.zero,
                        child: Stack(children: [
                          InteractiveViewer(
                            child: Image.network(_aiGeneratedImageUrl!,
                                fit: BoxFit.contain),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _aiGeneratedImageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                                ? child
                                : Container(
                                    height: 200,
                                    color: AppColors.softGray,
                                    child: const Center(
                                        child: CircularProgressIndicator(
                                            color: AppColors.gold)),
                                  ),
                        errorBuilder: (_, __, ___) => Container(
                          height: 140,
                          color: AppColors.softGray,
                          child: const Center(
                              child: Text('Could not load the design image',
                                  style: TextStyle(color: AppColors.goldDark))),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Tap the image to view it full screen',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  const SizedBox(height: 10),
                  if (_aiConfirmed)
                    const Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: AppColors.success, size: 16),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                              'Design selected - it will be attached to your order',
                              style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isGeneratingAi
                            ? null
                            : () => setState(() => _aiConfirmed = true),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Use this design'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.navyDeep,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
                if (_aiGenerationMessage != null &&
                    _aiGeneratedImageUrl == null) ...[
                  Text(
                    _aiGenerationMessage!,
                    style:
                        const TextStyle(color: AppColors.warning, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isGeneratingAi ? null : _generateAiDesign,
                        icon: _isGeneratingAi
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.gold))
                            : const Icon(Icons.auto_awesome_outlined, size: 16),
                        label: Text(_isGeneratingAi
                            ? 'Generating AI...'
                            : (_aiGeneratedImageUrl != null
                                ? 'Regenerate AI Preview'
                                : 'Generate AI Preview')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Delivery Address & Pricing Summary ──────────────────────────────
          AddressAutocompleteField(
            key: _addressFieldKey,
            api: widget.api,
            initialAddress: _addressCtrl.text,
            showRequiredRegionFields: true,
            onAddressSelected: (addr) {
              setState(() {
                _structuredAddress = addr;
                _addressCtrl.text = addr.fullDisplayAddress;
              });
            },
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text('Total Estimated Price:',
                          style: TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ),
                    if (_isCalculatingPrice)
                      const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.gold),
                      )
                    else
                      Text(
                        _calculatedPrice == null
                            ? 'Unavailable'
                            : money(_calculatedPrice),
                        style: const TextStyle(
                            color: AppColors.goldDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 20),
                      ),
                  ],
                ),
                if (_pricingError != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _isCalculatingPrice
                          ? null
                          : () => unawaited(_refreshServerQuote()),
                      icon: const Icon(Icons.refresh),
                      label: Text('Price unavailable. Retry: $_pricingError'),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                const Row(
                  children: [
                    Icon(Icons.savings_outlined,
                        color: AppColors.goldDark, size: 14),
                    SizedBox(width: 6),
                    Expanded(
                        child: Text(
                            'Eligible for ₹200 Promotional Cashback on confirmation',
                            style: TextStyle(
                                color: AppColors.goldDark, fontSize: 11))),
                  ],
                ),
                if (_minimumOrderShortfall > 0) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Minimum order ${money(2500)}. Increase the sign size by at least ${money(_minimumOrderShortfall.ceil())}.',
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submittingOrder ||
                            _isCalculatingPrice ||
                            _calculatedPrice == null ||
                            _minimumOrderShortfall > 0
                        ? null
                        : _submitSignageOrder,
                    icon: _submittingOrder
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.navy))
                        : const Icon(Icons.shopping_bag_rounded),
                    label: Text(
                      _submittingOrder
                          ? 'Submitting Order...'
                          : _isCalculatingPrice
                              ? 'Calculating server price...'
                              : _pricingError != null
                                  ? 'Retry price calculation'
                                  : _minimumOrderShortfall > 0
                                      ? 'Minimum order ${money(2500)}'
                                      : 'Order Signboard (${money(_calculatedPrice)})',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _colorCircle(Color color, String name, Color glow) {
    final isSel = _textColor.toARGB32() == color.toARGB32();
    return GestureDetector(
      key: ValueKey('signage-text-color-${color.toARGB32()}'),
      onTap: () => setState(() {
        _textColor = color;
        _textColorName = name;
        _glowColor = glow;
      }),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                  color: isSel ? AppColors.white : Colors.transparent,
                  width: 2.5),
              boxShadow: isSel
                  ? [
                      BoxShadow(
                          color: glow.withValues(alpha: .6),
                          blurRadius: 10,
                          spreadRadius: 1)
                    ]
                  : [],
            ),
          ),
          const SizedBox(height: 4),
          Text(name,
              style: TextStyle(
                  color: isSel ? AppColors.gold : AppColors.darkSecondary,
                  fontSize: 9.5)),
        ],
      ),
    );
  }
}
