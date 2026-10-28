import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/app_utils.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';
import '../../widgets/address_autocomplete_field.dart';

class PowerSupplyProduct {
  const PowerSupplyProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.outputVoltage,
    required this.wattage,
    required this.amperage,
    required this.inputVoltage,
    required this.ipRating,
    required this.price,
    required this.description,
    required this.specs,
    required this.bestFor,
    required this.icon,
  });

  final String id;
  final String name;
  final String category;
  final String outputVoltage;
  final int wattage;
  final double amperage;
  final String inputVoltage;
  final String ipRating;
  final double price;
  final String description;
  final List<String> specs;
  final String bestFor;
  final IconData icon;
}

class PowerSupplyScreen extends StatefulWidget {
  const PowerSupplyScreen({
    super.key,
    required this.api,
    this.promotionBannerId = 'home_banner_2',
    this.onOrderSubmitted,
  });

  final ApiClient api;
  final String promotionBannerId;
  final VoidCallback? onOrderSubmitted;

  @override
  State<PowerSupplyScreen> createState() => _PowerSupplyScreenState();
}

class _PowerSupplyScreenState extends State<PowerSupplyScreen> {
  static const List<PowerSupplyProduct> _catalog = [
    PowerSupplyProduct(
      id: 'ps_400w_12v',
      name: 'Slim Rainproof LED Power Supply 400W',
      category: 'Power Supply',
      outputVoltage: '12V DC',
      wattage: 400,
      amperage: 33.3,
      inputVoltage: 'AC 180–264V (50/60Hz)',
      ipRating: 'IP53 Rainproof',
      price: 1650,
      description:
          'Honeycomb ventilated aluminium housing with ultra-low thermal resistance for outdoor signboards.',
      specs: [
        'Output: 12V DC ± 2% / 33.3 Amperes',
        'Input: AC 180–264V 50/60Hz',
        'Efficiency: ≥ 88% at full load',
        'Protection: Short Circuit, Overload (110–150%), Over Temperature',
        'Cooling: Natural convection with honeycomb heat sink',
        'Warranty: 1 Year Manufacturer Replacement',
      ],
      bestFor:
          'Large 3D Acrylic letters, Neon flex installations, Outdoor store signs',
      icon: Icons.power_rounded,
    ),
    PowerSupplyProduct(
      id: 'ps_200w_12v',
      name: 'Compact Silent LED Driver 200W',
      category: 'LED Driver',
      outputVoltage: '12V DC',
      wattage: 200,
      amperage: 16.7,
      inputVoltage: 'AC 180–264V',
      ipRating: 'IP20 Indoor / Enclosed',
      price: 950,
      description:
          'Fanless 100% silent operation ideal for indoor boutique displays, cafés, and office signage.',
      specs: [
        'Output: 12V DC / 16.7 Amperes',
        'Efficiency: ≥ 89%',
        'Dimensions: 198 × 58 × 30 mm',
        'Built-in EMI filter with minimal harmonic distortion',
        'Warranty: 1 Year SignFix Warranty',
      ],
      bestFor:
          'Medium neon signs, back-lit letter signs, indoor boutique displays',
      icon: Icons.bolt_rounded,
    ),
    PowerSupplyProduct(
      id: 'ps_100w_thin',
      name: 'Ultra-Thin Concealed LED Driver 100W',
      category: 'LED Driver',
      outputVoltage: '12V DC',
      wattage: 100,
      amperage: 8.3,
      inputVoltage: 'AC 190–240V',
      ipRating: 'IP20 Concealed',
      price: 620,
      description:
          'Super-slim 18mm profile designed to fit hidden inside letter channels or narrow wall cavities.',
      specs: [
        'Output: 12V DC / 8.3 Amperes',
        'Profile Thickness: 18mm ultra-thin',
        'Short-circuit auto recovery protection',
        'High dielectric withstand voltage (3000VAC)',
      ],
      bestFor: 'Compact neon signs, under-cabinet signs, shelf signs',
      icon: Icons.compress_rounded,
    ),
    PowerSupplyProduct(
      id: 'ps_350w_ip67',
      name: 'Heavy Duty Waterproof IP67 Power Supply 350W',
      category: 'Waterproof Supply',
      outputVoltage: '12V DC',
      wattage: 350,
      amperage: 29.2,
      inputVoltage: 'AC 90–264V Universal',
      ipRating: 'IP67 Submersible / Waterproof',
      price: 2450,
      description:
          'Full epoxy silicone potted internal circuit with 4kV lightning surge protection for harsh outdoor climates.',
      specs: [
        'Output: 12V DC / 29.2 Amperes',
        'Waterproof Grade: IP67 (100% rain & jet spray proof)',
        'Surge Protection: L-N 2kV, L/N-PE 4kV',
        'Operating Temp: -30°C to +65°C',
        'Warranty: 2 Years Commercial Warranty',
      ],
      bestFor:
          'Exposed outdoor rooftop signs, pylon signboards, high-humidity environments',
      icon: Icons.water_drop_rounded,
    ),
    PowerSupplyProduct(
      id: 'ps_400w_24v',
      name: 'SignFix Dual Output LED Transformer 24V 400W',
      category: 'Transformer',
      outputVoltage: '24V DC',
      wattage: 400,
      amperage: 16.7,
      inputVoltage: 'AC 180–264V',
      ipRating: 'IP53 Rainproof',
      price: 1850,
      description:
          '24V architecture designed to halve line current and eliminate brightness drop across long cable runs.',
      specs: [
        'Output: 24V DC / 16.7 Amperes (Dual screw terminals)',
        'Significantly reduces voltage drop on cable runs exceeding 15 meters',
        'Heavy-duty aluminium casing with grounding lug',
        'Efficiency: 91%',
      ],
      bestFor:
          'Long neon strip runs, edge-lit panels, large architectural sign displays',
      icon: Icons.electrical_services_rounded,
    ),
    PowerSupplyProduct(
      id: 'ps_battery_backup',
      name: 'SignFix LiFePO4 Battery Backup Unit 12V 24Ah',
      category: 'Backup Solution',
      outputVoltage: '12V DC Stable',
      wattage: 288,
      amperage: 24.0,
      inputVoltage: 'AC 180–240V / Solar DC Input',
      ipRating: 'IP65 Weatherproof',
      price: 4800,
      description:
          'Keeps commercial signboards illuminated for 4-6 hours during load shedding and power cuts automatically.',
      specs: [
        'Capacity: 12.8V 24Ah LiFePO4 (over 2500 cycle life)',
        'Smart BMS with overcharge, deep discharge and thermal cutoff',
        'Switchover Time: Zero-break continuous illumination (< 5ms)',
        'Integrated digital voltage & charge indicator',
      ],
      bestFor:
          '24/7 business signs, pharmacy & hospital signs, standalone kiosk signage',
      icon: Icons.battery_charging_full_rounded,
    ),
    PowerSupplyProduct(
      id: 'ps_quick_connectors',
      name: 'DC Quick-Connect Wire Kit & IP68 Terminals (Pack of 5)',
      category: 'Accessories',
      outputVoltage: 'Up to 36V DC',
      wattage: 400,
      amperage: 35.0,
      inputVoltage: 'DC 12V/24V',
      ipRating: 'IP68 Waterproof',
      price: 380,
      description:
          'Heavy duty 14 AWG pure copper wires with screw-locking sealed connectors for fast and safe sign wiring.',
      specs: [
        '5 Sets of male/female waterproof screw-lock plugs',
        'Cable: 14 AWG double-insulated copper wire (30cm per pigtail)',
        'Rated Current: Up to 15A continuous per connector',
        'Eliminates soldering and messy electrical tape',
      ],
      bestFor:
          'Fast and safe electrical connection between sign letters and driver',
      icon: Icons.cable_rounded,
    ),
  ];

  late PowerSupplyProduct _selectedProduct;
  int _quantity = 1;
  bool _includeQuickConnectors = true;
  bool _includeMountingClips = true;
  final _addressCtrl = TextEditingController();
  StructuredAddress? _structuredAddress;
  bool _submitting = false;

  // Wattage Calculator inputs
  final _neonLengthCtrl = TextEditingController(text: '15');
  int _calculatedRecommendedWatts = 0;

  @override
  void initState() {
    super.initState();
    _selectedProduct = _catalog[0];
    _updateRecommendedWattage();
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _neonLengthCtrl.dispose();
    super.dispose();
  }

  void _updateRecommendedWattage() {
    final feet = double.tryParse(_neonLengthCtrl.text.trim()) ?? 0;
    // ~3.5W per foot + 20% safety margin
    final rawWatts = (feet * 3.5 * 1.2).ceil();
    setState(() {
      _calculatedRecommendedWatts = rawWatts > 0 ? rawWatts : 60;
    });
  }

  double get _subtotal {
    double total = _selectedProduct.price * _quantity;
    if (_includeQuickConnectors) total += 380;
    if (_includeMountingClips) total += 150;
    return total;
  }

    bool get _hasBannerMinimum =>
      requiresPromotionalOrderMinimum(widget.promotionBannerId);

  double get _minimumOrderShortfall =>
      _hasBannerMinimum ? orderMinimumShortfall(_subtotal) : 0;

  Future<void> _proceedToCheckout() async {
    if (_minimumOrderShortfall > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Minimum order is ${money(2500)}. Add ${money(_minimumOrderShortfall.ceil())} more to continue.',
          ),
        ),
      );
      return;
    }
    final address = _structuredAddress?.fullDisplayAddress.isNotEmpty == true
        ? _structuredAddress!.fullDisplayAddress
        : _addressCtrl.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter delivery / installation address.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final orderSpecs = {
        'product': 'LED Sign Board', // mapped to existing catalog product
        'category': 'Power Supply & Electrical Signage',
        'powerSupplyModel': _selectedProduct.name,
        'modelId': _selectedProduct.id,
        'outputVoltage': _selectedProduct.outputVoltage,
        'wattage': '${_selectedProduct.wattage}W',
        'amperage': '${_selectedProduct.amperage}A',
        'ipRating': _selectedProduct.ipRating,
        'quantity': _quantity,
        'includeQuickConnectors': _includeQuickConnectors,
        'includeMountingClips': _includeMountingClips,
        'length': 1.0,
        'width': 1.0,
        'material': 'Aluminium',
        'lighting': 'LED',
        'installation': false,
        'transportation': true,
        'address': address,
        'deliveryAddress': _structuredAddress?.toMap(),
        'saveAddress': _structuredAddress?.saveToProfile ?? false,
        'estimatedPrice': _subtotal,
        'idempotencyKey':
            '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32).toRadixString(16)}',
        'promotionBannerId': widget.promotionBannerId,
      };

      final order = await widget.api.createOrder(orderSpecs);
      final orderId = order['id']?.toString() ?? '';

      if (!mounted) return;
      setState(() => _submitting = false);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.navyDark,
          icon: const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 48),
          title: const Text('Order Placed Successfully',
              style: TextStyle(color: AppColors.white)),
          content: Text(
            'Order #$orderId has been submitted for ${_selectedProduct.name} (Qty: $_quantity).\n\nTotal: ₹${_subtotal.round()}\nPromotion Banner: ${widget.promotionBannerId} (Eligible for ₹200 Cashback upon payment confirmation).',
            style: const TextStyle(color: AppColors.textLight),
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
      setState(() => _submitting = false);
      if (mounted) {
        showAppError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text('Power Supply & Drivers',
                style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
            Text('Electrical Signage Components · Verified Specs',
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
          // ── Banner Header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.gold.withValues(alpha: .1), AppColors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.electrical_services_rounded,
                    color: AppColors.gold, size: 36),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Commercial Signboard Power Supplies',
                          style: TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                      SizedBox(height: 4),
                      Text(
                          'High-efficiency 12V/24V rainproof drivers, transformers, IP67 waterproof supplies & backup batteries.',
                          style: TextStyle(
                              color: AppColors.textBody,
                              fontSize: 11,
                              height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Live Wattage Load Advisor Tool ────────────────────────────────
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
                const Row(
                  children: [
                    Icon(Icons.calculate_outlined,
                        color: AppColors.gold, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Load Sizing Calculator',
                          style: TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                    'Enter estimated total neon length or sign outline to calculate recommended power wattage with safety headroom:',
                    style: TextStyle(color: AppColors.textBody, fontSize: 11)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _neonLengthCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                            color: AppColors.charcoal, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Estimated Neon Length (Feet)',
                          labelStyle: const TextStyle(fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          suffixText: 'ft',
                          suffixStyle:
                              const TextStyle(color: AppColors.textSecondary),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (_) => _updateRecommendedWattage(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.softGray,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          const Text('Recommended',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 9)),
                          Text('≥ ${_calculatedRecommendedWatts}W',
                              style: const TextStyle(
                                  color: AppColors.goldDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ── Product Catalog Section ─────────────────────────────────────────
          const Text('Select Power Supply or Driver',
              style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _catalog.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final item = _catalog[i];
              final isSelected = _selectedProduct.id == item.id;
              final isRecommended =
                  item.wattage >= _calculatedRecommendedWatts &&
                      item.category.contains('Supply');

              return GestureDetector(
                onTap: () => setState(() => _selectedProduct = item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.gold : AppColors.cardBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.softGray,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(item.icon,
                                color: AppColors.goldDark, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(item.name,
                                          style: const TextStyle(
                                              color: AppColors.navy,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13)),
                                    ),
                                    Text('₹${item.price.round()}',
                                        style: const TextStyle(
                                            color: AppColors.goldDark,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _specPill(
                                        item.outputVoltage, AppColors.goldDark),
                                    _specPill(
                                        '${item.wattage}W', AppColors.navy),
                                    _specPill(
                                        item.ipRating, AppColors.navyDeep),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(item.description,
                          style: const TextStyle(
                              color: AppColors.textBody, fontSize: 11)),
                      if (isRecommended) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.softGray,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                              '✓ Ideal capacity for your calculated length',
                              style: TextStyle(
                                  color: AppColors.goldDark,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 22),

          // ── Selected Product Detailed Specifications ────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_outlined,
                        color: AppColors.gold, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Datasheet: ${_selectedProduct.name}',
                          style: const TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._selectedProduct.specs.map(
                  (s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.bold)),
                        Expanded(
                            child: Text(s,
                                style: const TextStyle(
                                    color: AppColors.textBody,
                                    fontSize: 11,
                                    height: 1.3))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Best Applications: ${_selectedProduct.bestFor}',
                    style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 11,
                        fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Configuration & Quantity ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Order Configuration',
                    style: TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Quantity Units',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: AppColors.textSecondary),
                      onPressed: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                    ),
                    Text('$_quantity',
                        style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          color: AppColors.gold),
                      onPressed: () => setState(() => _quantity++),
                    ),
                  ],
                ),
                const Divider(color: AppColors.cardBorder, height: 20),
                Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.gold,
                    title: const Text('Include IP68 Quick-Connect Terminal Kit',
                        style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Pack of 5 waterproof screw-lock male/female pigtails (+₹380)',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 10)),
                    value: _includeQuickConnectors,
                    onChanged: (v) =>
                        setState(() => _includeQuickConnectors = v ?? false),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.gold,
                    title: const Text(
                        'Include Aluminium Mounting Clamps & Screws',
                        style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Wall standoffs & anti-vibration silicon pads (+₹150)',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 10)),
                    value: _includeMountingClips,
                    onChanged: (v) =>
                        setState(() => _includeMountingClips = v ?? false),
                  ),
                ),
                const SizedBox(height: 12),
                AddressAutocompleteField(
                  api: widget.api,
                  initialAddress: _addressCtrl.text,
                  onAddressSelected: (addr) {
                    setState(() {
                      _structuredAddress = addr;
                      _addressCtrl.text = addr.fullDisplayAddress;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Checkout summary card ───────────────────────────────────────────
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
                    Text('₹${_subtotal.round()}',
                        style: const TextStyle(
                            color: AppColors.goldDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 20)),
                  ],
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: AppColors.goldDark, size: 14),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          'Eligible for ₹200 Cashback credited upon payment',
                          style: TextStyle(
                              color: AppColors.goldDark, fontSize: 11)),
                    ),
                  ],
                ),
                if (_minimumOrderShortfall > 0) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Minimum order ${money(2500)}. Add ${money(_minimumOrderShortfall.ceil())} more.',
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
                    onPressed: _submitting || _minimumOrderShortfall > 0
                        ? null
                        : _proceedToCheckout,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.navy))
                        : const Icon(Icons.shopping_bag_outlined),
                    label: Text(
                      _submitting
                          ? 'Submitting Order...'
                          : _minimumOrderShortfall > 0
                              ? 'Minimum order ${money(2500)}'
                              : 'Order Power Supply (${money(_subtotal)})',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _specPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.softGray,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9.5, fontWeight: FontWeight.w700)),
    );
  }
}
