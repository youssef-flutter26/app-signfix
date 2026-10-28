import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/app_theme.dart';
import '../../core/app_utils.dart';
import '../../services/api_client.dart';
import '../../services/latest_request_gate.dart';
import '../../services/pricing_conflict_flow.dart';
import '../../widgets/common.dart';
import '../../widgets/address_autocomplete_field.dart';
import 'text_designer_screen.dart';

class OrderWizard extends StatefulWidget {
  const OrderWizard({
    super.key,
    required this.api,
    this.onOrderSubmitted,
    this.promotionBannerNotifier,
  });
  final ApiClient api;
  final VoidCallback? onOrderSubmitted;
  final ValueNotifier<String?>? promotionBannerNotifier;
  @override
  State<OrderWizard> createState() => _OrderWizardState();
}

class _OrderWizardState extends State<OrderWizard> {
  int step = 0;
  String type = 'LED Sign Board', material = 'Acrylic', lighting = 'LED';
  String unit = 'ft';
  final length = TextEditingController(text: '10');
  final width = TextEditingController(text: '3');
  final quantity = TextEditingController(text: '1');
  final address = TextEditingController();
  final remarks = TextEditingController();
  bool installation = true, transportation = true, loading = false;
  bool design = false,
      electricalWork = false,
      mountingStructure = false,
      accessories = false,
      customization = false;
  Map<String, dynamic>? quote;
  Map<String, dynamic>? _orderOptions;
  String? _optionsError;
  String? _quoteError;
  final List<Map<String, String>> _designFiles = [];
  bool _uploadingDesign = false;
  double _uploadProgress = 0;
  bool _recalculating = false;
  Timer? _calculationTimer;
  final LatestRequestGate _calculationGate = LatestRequestGate();
  bool _quoteIsCurrent = false;
  SignBoardTextDesign? _textDesign;
  StructuredAddress? _structuredDeliveryAddress;

  // ── Step 4 Payment state ──────────────────────────────────────────────────
  late final Razorpay _razorpay;
  bool _payProcessing = false;
  bool _payLaunched = false;
  String? _payIntentId;
  String? _payError;
  bool _payPending = false;
  bool _paySuccess = false;
  String _payMethod = 'upi';
  bool _useWallet = false;
  bool _walletLoading = true;
  String? _walletError;
  Map<String, dynamic>? _walletData;
  String? _promotionBannerId;
  String? _cashbackStatus;
  double? _orderPayableTotal;
  double? _walletAppliedOnOrder;
  String _orderIdempotencyKey = _newIdempotencyKey();
  String _ledWatt = '10W';
  String? _sideWalling;
  final _upiController = TextEditingController();
  String? _upiError;
  Map<String, dynamic>? _customerProfile;
  static final _upiRegex = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,}$');

  // Payment type
  String _paymentType = 'full';

  String _submittedOrderNo = '';
  bool _orderSubmitted = false;

  // Net banking
  String? _selectedBank;

  // Wallets
  String? _selectedWallet;

  // EMI
  int? _emiMonths;

  // 5 steps: 0-TextDesign · 1-Type · 2-Dimensions · 3-Finish · 4-Estimate
  static const _totalSteps = 5;

  static const _types = [
    'LED Sign Board',
    'Acrylic Sign Board',
    'Flex Sign Board',
    'Glow Sign Board',
    '3D Letter',
    'Channel Letter',
    'Neon Sign',
    'Backlit Sign',
    'Outdoor Signage',
    'Custom Sign Board',
    'Module LED Letters',
    'Channel LED Letters',
    'Bata Type LED Letters',
  ];
  static const _materials = [
    'Acrylic',
    'ACP',
    'PVC',
    'Flex',
    'Stainless Steel',
    'Aluminium'
  ];
  static const _lightings = [
    'No Lighting',
    'LED',
    'Backlit',
    'Neon',
    'Front Lit',
    'Custom'
  ];
  static const _wattOptions = [
    '5W',
    '10W',
    '12W',
    '15W',
    '18W',
    '20W',
    '24W',
    '30W',
    '40W',
    '50W'
  ];

  @override
  void initState() {
    super.initState();
    _promotionBannerId = widget.promotionBannerNotifier?.value;
    widget.promotionBannerNotifier?.addListener(_onPromotionBannerChanged);
    unawaited(_loadOrderOptions());
    length.addListener(_scheduleCalculation);
    width.addListener(_scheduleCalculation);
    quantity.addListener(_scheduleCalculation);
    unawaited(_loadWallet());
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPayError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onPayWallet);
  }

  static String _newIdempotencyKey() {
    final random = Random.secure();
    return '${DateTime.now().microsecondsSinceEpoch}-'
        '${random.nextInt(1 << 32).toRadixString(16)}-'
        '${random.nextInt(1 << 32).toRadixString(16)}';
  }

  void _onPromotionBannerChanged() {
    _promotionBannerId = widget.promotionBannerNotifier?.value;
  }

  Future<void> _loadOrderOptions() async {
    try {
      final options = await widget.api.orderOptions();
      if (!mounted) return;
      setState(() {
        _orderOptions = options;
        _optionsError = null;
        final types = _optionNames('signBoardTypes');
        final materials = _optionNames('materials');
        final lightingOptions = _optionNames('lighting');
        final units = _unitOptions;
        if (types.isNotEmpty && !types.contains(type)) type = types.first;
        if (materials.isNotEmpty && !materials.contains(material)) {
          material = materials.first;
        }
        if (lightingOptions.isNotEmpty && !lightingOptions.contains(lighting)) {
          lighting = lightingOptions.first;
        }
        if (units.isNotEmpty && !units.contains(unit)) unit = units.first;
      });
      _scheduleCalculation();
    } catch (error) {
      if (mounted) setState(() => _optionsError = error.toString());
    }
  }

  List<String> _optionNames(String key) {
    final values = _orderOptions?[key];
    if (values is List) {
      return values
          .map((value) => value is Map ? value['name']?.toString() : null)
          .whereType<String>()
          .where((name) => name.isNotEmpty)
          .toList();
    }
    if (!widget.api.mockMode) return const [];
    return switch (key) {
      'signBoardTypes' => _types,
      'materials' => _materials,
      'lighting' => _lightings,
      _ => const [],
    };
  }

  List<String> get _unitOptions {
    final values = _orderOptions?['units'];
    if (values is List) return values.map((value) => value.toString()).toList();
    return widget.api.mockMode ? const ['ft', 'in', 'cm', 'm'] : const [];
  }

  void _scheduleCalculation() {
    _calculationTimer?.cancel();
    _calculationGate.invalidate();
    if (_quoteIsCurrent && mounted) {
      setState(() {
        _quoteIsCurrent = false;
        _recalculating = true;
        _quoteError = null;
      });
    }
    _calculationTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || _orderOptions == null) return;
      final parsedLength = double.tryParse(length.text);
      final parsedWidth = double.tryParse(width.text);
      final parsedQuantity = int.tryParse(quantity.text);
      if (parsedLength == null ||
          parsedLength <= 0 ||
          parsedWidth == null ||
          parsedWidth <= 0 ||
          parsedQuantity == null ||
          parsedQuantity <= 0) {
        setState(() {
          _recalculating = false;
          _quoteError =
              'Enter positive dimensions and quantity to recalculate.';
        });
        return;
      }
      _calculate(advance: false);
    });
  }

  Future<void> _loadWallet() async {
    if (mounted && !_walletLoading) {
      setState(() {
        _walletLoading = true;
        _walletError = null;
      });
    }
    try {
      final wallet = await widget.api.wallet();
      if (mounted) setState(() => _walletData = wallet);
    } catch (error) {
      if (mounted) setState(() => _walletError = error.toString());
    } finally {
      if (mounted) setState(() => _walletLoading = false);
    }
  }

  bool get _isPromotionEligible {
    final bannerId = _promotionBannerId;
    return bannerId != null &&
        const {'home_banner_1', 'home_banner_2', 'home_banner_3'}
            .contains(bannerId);
  }

  double get _walletBalance {
    final balance = _walletData?['balance'];
    return balance is num ? balance.toDouble() : 0;
  }

  double _walletAppliedTo(double total) {
    if (_orderSubmitted) return _walletAppliedOnOrder ?? 0;
    return _useWallet ? _walletBalance.clamp(0, total).toDouble() : 0;
  }

  double _amountToPay(double total) =>
      (total - _walletAppliedTo(total)).clamp(0, double.infinity).toDouble();

  double get _checkoutPayableTotal => _orderSubmitted
      ? (_orderPayableTotal ?? 0)
      : _amountToPay(_quotePrice('estimatedPrice'));

  double get _checkoutPayAmount =>
      _checkoutPayableTotal * (_paymentType == 'advance' ? 0.25 : 1);

  @override
  void dispose() {
    widget.promotionBannerNotifier?.removeListener(_onPromotionBannerChanged);
    _razorpay.clear();
    _calculationTimer?.cancel();
    _upiController.dispose();
    for (final c in [length, width, quantity, address]) {
      c.dispose();
    }
    remarks.dispose();
    super.dispose();
  }

  void _err(Object e) => showAppError(context, e);

  // Map new sign types to existing backend product names
  // New types (Module/Channel/Bata) map to 'LED Sign Board' in DB
  // until admin adds them to the products catalog
  String get _backendProductName {
    return type;
  }

  Map<String, dynamic> _pricingInput() => {
        'product': _backendProductName,
        'length': double.parse(length.text),
        'width': double.parse(width.text),
        'unit': unit,
        'quantity': int.parse(quantity.text),
        'material': material,
        'lighting': lighting,
        'installation': installation,
        'transportation': transportation,
        'design': design,
        'electricalWork': electricalWork,
        'mountingStructure': mountingStructure,
        'accessories': accessories,
        'customization': customization,
        'ledWatt': _ledWatt,
      };

  Future<bool> _calculate({bool advance = true}) async {
    final l = double.tryParse(length.text);
    final w = double.tryParse(width.text);
    final q = int.tryParse(quantity.text);
    if (l == null || w == null || q == null || l <= 0 || w <= 0 || q <= 0) {
      if (advance) _err('Enter valid dimensions and quantity.');
      return false;
    }
    final requestId = _calculationGate.begin();
    if (mounted) {
      setState(() {
        loading = advance;
        _recalculating = !advance;
        _quoteIsCurrent = false;
        _quoteError = null;
      });
    }
    try {
      final result = await widget.api.calculate({
        ..._pricingInput(),
        if (_textDesign != null) 'signText': _textDesign!.text,
        if (_textDesign != null) 'signFont': _textDesign!.fontFamily,
      });
      if (mounted && _calculationGate.isLatest(requestId)) {
        setState(() {
          quote = result;
          _quoteIsCurrent = true;
          if (advance) step = 4;
        });
      }
      return _calculationGate.isLatest(requestId);
    } catch (e) {
      if (mounted && _calculationGate.isLatest(requestId)) {
        setState(() => _quoteError = e.toString());
        if (advance) _err(e);
      }
      return false;
    } finally {
      if (mounted && _calculationGate.isLatest(requestId)) {
        setState(() {
          loading = false;
          _recalculating = false;
        });
      }
    }
  }

  Future<bool> _submitOrder({bool retryAfterPriceChange = true}) async {
    if (quote == null || !_quoteIsCurrent) return false;
    setState(() => loading = true);
    try {
      final order = await widget.api.createOrder({
        ..._pricingInput(),
        'address':
            _structuredDeliveryAddress?.fullDisplayAddress.isNotEmpty == true
                ? _structuredDeliveryAddress!.fullDisplayAddress
                : address.text.trim(),
        'remarks': remarks.text.trim(),
        'deliveryAddress': _structuredDeliveryAddress?.toMap(),
        'saveAddress': _structuredDeliveryAddress?.saveToProfile ?? false,
        'estimatedPrice': quote!['estimatedPrice'],
        'designFiles': _designFiles.map((file) => file['url']).toList(),
        'idempotencyKey': _orderIdempotencyKey,
        'useWallet': _useWallet,
        if (_promotionBannerId != null) 'promotionBannerId': _promotionBannerId,
        if (_sideWalling != null) 'sideWalling': _sideWalling!,
        if (_textDesign != null) 'signText': _textDesign!.text,
        if (_textDesign != null) 'signFont': _textDesign!.fontFamily,
        if (_textDesign != null)
          'signColor': _textDesign!.color.toARGB32().toRadixString(16),
      });
      final id = order['id']?.toString();
      if (id == null || id.isEmpty) {
        throw const ApiException(
          'The server did not return the new order number.',
        );
      }
      if (!mounted) return false;
      setState(() {
        _submittedOrderNo = id;
        _orderSubmitted = true;
        _orderPayableTotal = (order['estimatedPrice'] as num?)?.toDouble() ??
            _quotePrice('estimatedPrice');
        _walletAppliedOnOrder =
            (order['walletDiscountApplied'] as num?)?.toDouble() ?? 0;
        _cashbackStatus = order['cashbackStatus']?.toString();
        _payError = null;
        _payPending = false;
      });
      unawaited(_loadWallet());
      return true;
    } catch (e) {
      if (e is ApiException && e.statusCode == 409 && retryAfterPriceChange) {
        final oldPrice = _quotePrice('estimatedPrice');
        final recovered = await recoverFromPricingConflict(
          recalculate: () => _calculate(advance: false),
          confirmUpdatedPrice: () async {
            if (!mounted) return false;
            return await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Price updated'),
                    content: Text(
                      'The server price changed from ${money(oldPrice)} to ${money(_quotePrice('estimatedPrice'))}. Review the updated estimate and confirm to continue.',
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
          },
          retrySubmission: () {
            if (!mounted) return Future.value(false);
            _orderIdempotencyKey = _newIdempotencyKey();
            return _submitOrder(retryAfterPriceChange: false);
          },
        );
        if (!recovered && mounted) {
          setState(() => _payError =
              'Order was not submitted. Review the refreshed estimate before continuing.');
        }
        return recovered;
      }
      debugPrint('OrderWizard order submission failed: $e');
      if (mounted) {
        setState(() {
          _payError = e.toString();
          _payPending = false;
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _reset() {
    _designFiles.clear();
    setState(() {
      step = 0;
      type = 'LED Sign Board';
      material = 'Acrylic';
      lighting = 'LED';
      length.text = '10';
      width.text = '3';
      quantity.text = '1';
      address.clear();
      remarks.clear();
      installation = true;
      transportation = true;
      quote = null;
      _quoteIsCurrent = false;
      _quoteError = null;
      _textDesign = null;
      _structuredDeliveryAddress = null;
      _payProcessing = false;
      _payLaunched = false;
      _payIntentId = null;
      _payError = null;
      _payPending = false;
      _paySuccess = false;
      _upiController.clear();
      _upiError = null;
      _customerProfile = null;
      _ledWatt = '10W';
      _sideWalling = null;
      _paymentType = 'full';
      _useWallet = false;
      _submittedOrderNo = '';
      _orderPayableTotal = null;
      _walletAppliedOnOrder = null;
      _cashbackStatus = null;
      _orderSubmitted = false;
      _orderIdempotencyKey = _newIdempotencyKey();
      widget.promotionBannerNotifier?.value = null;
      _promotionBannerId = null;
      _selectedBank = null;
      _selectedWallet = null;
      _emiMonths = null;
    });
    unawaited(_loadWallet());
  }

  Future<void> _pickAndUploadDesign() async {
    if (_uploadingDesign) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final path = file.path;
    if (path == null) {
      _err('This file cannot be accessed. Choose another file.');
      return;
    }
    if (file.size > 8 * 1024 * 1024) {
      _err('The design file must be 8 MB or smaller.');
      return;
    }
    setState(() {
      _uploadingDesign = true;
      _uploadProgress = 0;
    });
    try {
      final response = await widget.api.uploadDesign(
        File(path),
        onProgress: (sent, total) {
          if (mounted) {
            setState(() => _uploadProgress = total == 0 ? 0 : sent / total);
          }
        },
      );
      final url = response['url']?.toString();
      if (url == null || url.isEmpty) {
        throw const ApiException(
            'The server did not return the uploaded file URL.');
      }
      if (mounted) {
        setState(() => _designFiles.add({'name': file.name, 'url': url}));
      }
    } catch (error) {
      if (mounted) _err(error);
    } finally {
      if (mounted) setState(() => _uploadingDesign = false);
    }
  }

  // ── Payment methods ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _getProfile() async {
    _customerProfile ??= await widget.api.getProfile();
    return _customerProfile!;
  }

  Future<void> _payAndSubmit() async {
    debugPrint(
      'OrderWizard payment requested: method=$_payMethod, '
      'orderSubmitted=$_orderSubmitted, hasOrderNo=${_submittedOrderNo.isNotEmpty}',
    );
    if (_payLaunched || _payProcessing) {
      debugPrint(
          'OrderWizard payment ignored: another payment is in progress.');
      return;
    }
    if (!_orderSubmitted && !_quoteIsCurrent) {
      _err('Please wait for the latest price estimate before submitting.');
      return;
    }

    final estimatedPayAmount = _orderSubmitted
        ? _checkoutPayAmount
        : _amountToPay(_quotePrice('estimatedPrice')) *
            (_paymentType == 'advance' ? 0.25 : 1);
    if (estimatedPayAmount > 0 && _payMethod == 'upi') {
      final upiId = _upiController.text.trim();
      if (upiId.isNotEmpty && !_upiRegex.hasMatch(upiId)) {
        setState(() => _upiError = 'Enter a valid UPI ID (e.g. username@bank)');
        return;
      }
    } else if (estimatedPayAmount > 0 && _payMethod == 'netbanking') {
      if (_selectedBank == null) {
        setState(() => _payError =
            'Please select a bank. You will enter your banking details securely in Razorpay.');
        return;
      }
    } else if (estimatedPayAmount > 0 && _payMethod == 'wallet') {
      if (_selectedWallet == null) {
        setState(() => _payError =
            'Please select a wallet. You will authorize it securely in Razorpay.');
        return;
      }
    } else if (estimatedPayAmount > 0 && _payMethod == 'emi') {
      if (_emiMonths == null) {
        setState(() => _payError = 'Please select an EMI plan.');
        return;
      }
    }

    if (_upiError != null) setState(() => _upiError = null);

    setState(() {
      _payProcessing = true;
      _payLaunched = false;
      _payIntentId = null;
      _payError = null;
      _payPending = false;
      _paySuccess = false;
    });

    try {
      if (!_orderSubmitted) {
        debugPrint('OrderWizard creating order before launching payment.');
        final submitted = await _submitOrder();
        if (!submitted || !mounted) {
          if (mounted) setState(() => _payProcessing = false);
          return;
        }
      }

      if (!mounted) return;
      if (_submittedOrderNo.isEmpty) {
        setState(() {
          _payProcessing = false;
          _payError =
              'The server did not return the order number needed to start payment. Please contact support.';
          _payPending = true;
        });
        return;
      }

      debugPrint('OrderWizard loading customer profile for Razorpay checkout.');
      final profile = await _getProfile();
      final estimatedPrice = _orderPayableTotal ??
          (quote!['estimatedPrice'] as num?)?.toDouble() ??
          0;
      final payAmount =
          _paymentType == 'advance' ? estimatedPrice * 0.25 : estimatedPrice;
      if (payAmount <= 0) {
        if (!mounted) return;
        setState(() {
          _payProcessing = false;
          _paySuccess = true;
          _payPending = false;
        });
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.white,
            icon: const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 48),
            title: const Text('Order Placed',
                style: TextStyle(color: AppColors.navy)),
            content: Text(
              'Your wallet covered the payable amount for order $_submittedOrderNo.',
              style: const TextStyle(color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _reset();
                  widget.onOrderSubmitted?.call();
                },
                child: const Text('View Orders'),
              ),
            ],
          ),
        );
        return;
      }
      if (_payMethod == 'upi') {
        final upiId = _upiController.text.trim();
        if (upiId.isNotEmpty && !_upiRegex.hasMatch(upiId)) {
          setState(() {
            _payProcessing = false;
            _upiError = 'Enter a valid UPI ID (e.g. username@bank)';
          });
          return;
        }
      } else if (_payMethod == 'netbanking' && _selectedBank == null) {
        setState(() {
          _payProcessing = false;
          _payError =
              'Please select a bank. You will enter your banking details securely in Razorpay.';
        });
        return;
      } else if (_payMethod == 'wallet' && _selectedWallet == null) {
        setState(() {
          _payProcessing = false;
          _payError =
              'Please select a wallet. You will authorize it securely in Razorpay.';
        });
        return;
      } else if (_payMethod == 'emi' && _emiMonths == null) {
        setState(() {
          _payProcessing = false;
          _payError = 'Please select an EMI plan.';
        });
        return;
      }
      debugPrint(
        'OrderWizard creating payment intent: type=$_paymentType, '
        'amountRupees=$payAmount.',
      );

      String keyId = 'rzp_live_TZRwgnPCEkDeu4';
      String? providerOrderId;
      String currency = 'INR';
      int amountInPaise = (payAmount * 100).round();
      String checkoutName = 'SignFix';
      String checkoutDesc = 'Order $_submittedOrderNo ($_paymentType)';

      try {
        final intent = await widget.api.createOrderPaymentIntent({
          'orderNo': _submittedOrderNo,
          'type': _paymentType,
          'amount': payAmount,
          'idempotencyKey': '${DateTime.now().microsecondsSinceEpoch}-'
              '${Random.secure().nextInt(1 << 32).toRadixString(16)}',
        });
        debugPrint('OrderWizard payment intent response received: $intent');
        _payIntentId = intent['id']?.toString();
        final checkoutValue = intent['checkout'];
        if (checkoutValue is Map) {
          final checkout = Map<String, dynamic>.from(checkoutValue);
          final k = checkout['keyId']?.toString();
          if (k != null && k.isNotEmpty) keyId = k;
          final oId = checkout['orderId']?.toString();
          if (oId != null && oId.startsWith('order_')) providerOrderId = oId;
          final amt = checkout['amount'];
          if (amt is num && amt > 0) amountInPaise = amt.round();
          final c = checkout['currency']?.toString();
          if (c != null && c.isNotEmpty) currency = c;
          final n = checkout['name']?.toString();
          if (n != null && n.isNotEmpty) checkoutName = n;
          final d = checkout['description']?.toString();
          if (d != null && d.isNotEmpty) checkoutDesc = d;
        }
      } catch (intentErr) {
        debugPrint('Backend payment intent error: $intentErr');
        if (!mounted) return;
        setState(() {
          _payProcessing = false;
          _payError =
              'Could not initialize payment session: $intentErr. Please retry.';
        });
        return;
      }

      debugPrint(
        'OrderWizard opening Razorpay: keyId=$keyId, currency=$currency, '
        'amountPaise=$amountInPaise, orderId=$providerOrderId.',
      );

      final prefill = <String, dynamic>{
        'name': profile['name']?.toString() ?? '',
        'email': profile['email']?.toString() ?? '',
        'contact':
            profile['phone']?.toString() ?? profile['mobile']?.toString() ?? '',
      };

      if (_payMethod == 'upi') {
        prefill['method'] = 'upi';
        final vpa = _upiController.text.trim();
        if (vpa.isNotEmpty) {
          prefill['vpa'] = vpa;
        }
      } else if (_payMethod == 'card') {
        prefill['method'] = 'card';
      } else if (_payMethod == 'netbanking') {
        prefill['method'] = 'netbanking';
        if (_selectedBank != null) {
          const bankMap = {
            'SBI': 'SBIN',
            'HDFC Bank': 'HDFC',
            'ICICI Bank': 'ICIC',
            'Axis Bank': 'UTIB',
            'Kotak Mahindra': 'KKBK',
            'Punjab National Bank': 'PUNB_R',
            'Bank of Baroda': 'BARB_R',
            'Canara Bank': 'CNRB',
            'Yes Bank': 'YESB',
            'IDBI Bank': 'IBKL',
          };
          final bankCode = bankMap[_selectedBank];
          if (bankCode != null) prefill['bank'] = bankCode;
        }
      } else if (_payMethod == 'wallet') {
        prefill['method'] = 'wallet';
        if (_selectedWallet != null) {
          prefill['wallet'] = _selectedWallet!.toLowerCase();
        }
      } else if (_payMethod == 'emi') {
        prefill['method'] = 'emi';
      }

      final options = <String, dynamic>{
        'key': keyId,
        'amount': amountInPaise,
        'currency': currency,
        'name': checkoutName,
        'description': checkoutDesc,
        if (providerOrderId != null && providerOrderId.isNotEmpty)
          'order_id': providerOrderId,
        'prefill': prefill,
        'theme': {
          'color': '#F5A800',
        },
      };

      _razorpay.open(options);

      setState(() {
        _payLaunched = true;
        _payProcessing = false;
      });
      debugPrint('OrderWizard Razorpay checkout opened successfully.');
    } catch (e) {
      debugPrint('OrderWizard payment setup failed: $e');
      if (!mounted) return;
      setState(() {
        _payProcessing = false;
        String msg = e.toString().replaceFirst(
            RegExp(r'^(Exception|ApiException|ClientException):\s*'), '');
        if (msg.contains('Connection closed before full header') ||
            msg.contains('connection was closed')) {
          msg =
              'Connection to payment gateway timed out or server dropped. You can retry or view your order.';
        }
        _payError = msg;
        _payPending = false;
      });
    }
  }

  void _onPaySuccess(PaymentSuccessResponse resp) {
    debugPrint(
      'OrderWizard Razorpay success callback received: '
      'paymentIdPresent=${resp.paymentId != null}, '
      'orderIdPresent=${resp.orderId != null}, '
      'signaturePresent=${resp.signature != null}.',
    );
    unawaited(_verifyAndSubmit(resp));
  }

  Future<void> _verifyAndSubmit(PaymentSuccessResponse resp) async {
    debugPrint('OrderWizard verifying Razorpay payment with backend.');
    final intentId = _payIntentId;
    final paymentId = resp.paymentId;
    final providerOrderId = resp.orderId;
    final signature = resp.signature;

    if (paymentId == null || paymentId.isEmpty) {
      _setPayPending(
        'Razorpay did not return a payment ID. Please contact support.',
      );
      return;
    }

    setState(() {
      _payProcessing = true;
      _payError = null;
    });

    try {
      if (intentId != null && providerOrderId != null && signature != null) {
        final verified = await widget.api.verifyPayment(intentId, {
          'razorpayPaymentId': paymentId,
          'razorpayOrderId': providerOrderId,
          'razorpaySignature': signature,
        });
        debugPrint(
          'OrderWizard payment verification result: status=${verified['status']}.',
        );
        final status = (verified['status'] ?? '').toString().toLowerCase();
        if (status != 'captured' && status != 'authorized') {
          if (status == 'failed') {
            throw Exception('Payment was marked as failed by the gateway.');
          } else {
            _setPayPending(
                'Payment is currently pending verification. Status: $status');
            return;
          }
        }
      } else {
        _setPayPending(
          'Payment completed with Razorpay (ID: $paymentId), but verification signature was missing. Please contact support.',
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _payProcessing = false;
        _paySuccess = true;
        _payPending = false;
        _payError = null;
      });
      unawaited(_loadWallet());
      // Order already created before payment — just show success dialog
      if (mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.white,
            icon: const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 48),
            title: const Text('Payment Successful!',
                style: TextStyle(color: AppColors.navy)),
            content: Text(
              'Your payment for order $_submittedOrderNo was received.\n\nAdmin will review the order before production.',
              style: const TextStyle(color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _reset();
                  widget.onOrderSubmitted?.call();
                },
                child: const Text('View Orders'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('OrderWizard payment verification failed: $e');
      _setPayPending(
        'Payment was received but could not be verified: $e. '
        'Do not pay again; check your payment status or contact support.',
      );
    }
  }

  void _onPayError(PaymentFailureResponse resp) {
    debugPrint(
      'OrderWizard Razorpay failure callback: code=${resp.code}, '
      'message=${resp.message}.',
    );
    unawaited(_handlePayError(resp));
  }

  Future<void> _handlePayError(PaymentFailureResponse resp) async {
    final intentId = _payIntentId;
    final message = _friendlyPayError(resp);
    if (intentId != null) {
      try {
        await widget.api.reportPaymentFailure(intentId, {
          if (resp.code != null) 'code': resp.code.toString(),
          'description': resp.message ?? 'Razorpay payment failed',
          'source': 'razorpay',
          'step': 'checkout',
        });
      } catch (error) {
        debugPrint('OrderWizard could not report payment failure: $error');
      }
    }
    if (!mounted) return;
    setState(() {
      _payProcessing = false;
      _payLaunched = false;
      _payError = message;
    });
  }

  String _friendlyPayError(PaymentFailureResponse resp) {
    final code = resp.code ?? 0;
    final raw = (resp.message ?? '').toLowerCase();
    if (code == Razorpay.PAYMENT_CANCELLED ||
        raw.contains('cancel') ||
        raw.contains('dismiss')) {
      return 'You cancelled the payment. You can try again whenever you\'re ready.';
    }
    if (code == Razorpay.NETWORK_ERROR ||
        raw.contains('network') ||
        raw.contains('timeout') ||
        raw.contains('connect')) {
      return 'Unable to connect to the payment service. Please check your internet connection and try again.';
    }
    if (raw.contains('insufficient') || raw.contains('low balance')) {
      return 'Insufficient funds. Please try another payment method.';
    }
    if (raw.contains('declined') || raw.contains('do not honour')) {
      return 'Payment declined by your bank. Please try another method.';
    }
    final cleanMsg = resp.message
            ?.replaceAll(RegExp(r'Exception:?\s*'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim() ??
        '';
    if (cleanMsg.isNotEmpty && cleanMsg.length < 120) return cleanMsg;
    return 'Payment could not be completed. Please try a different payment method or contact support.';
  }

  void _onPayWallet(ExternalWalletResponse resp) {
    _setPayPending(
      'The ${resp.walletName} payment was started. '
      'Check your payment status before trying again.',
    );
  }

  void _setPayPending(String message) {
    if (!mounted) return;
    setState(() {
      _payProcessing = false;
      _payPending = true;
      _payError = message;
      _payLaunched = false;
    });
  }

  // ── Step validation ──────────────────────────────────────────────────────
  bool _validateStep() {
    switch (step) {
      case 0:
        // Text designer step — optional, always allow next
        return true;
      case 1:
        // Sign type — already has default value, always valid
        return true;
      case 2:
        // Dimensions + address
        final l = double.tryParse(length.text);
        final w = double.tryParse(width.text);
        final q = int.tryParse(quantity.text);
        if (l == null || l <= 0) {
          _showValidationError('Please enter a valid length (ft).');
          return false;
        }
        if (w == null || w <= 0) {
          _showValidationError('Please enter a valid width (ft).');
          return false;
        }
        if (q == null || q <= 0) {
          _showValidationError('Please enter a valid quantity.');
          return false;
        }
        if (address.text.trim().isEmpty) {
          _showValidationError(
              'Please enter the delivery / installation address.');
          return false;
        }
        return true;
      case 3:
        // Finish & options — material/lighting already have defaults
        return true;
      default:
        return true;
    }
  }

  void _showValidationError(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.warning_amber_rounded,
            color: AppColors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  void _nextStep() {
    if (_validateStep()) setState(() => step++);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softGray,
      body: Column(
        children: [
          // ── Scrollable content ─────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              children: _buildStepContent(),
            ),
          ),

          // ── Nav row — always pinned at bottom ──────────────────────────
          if (step < 4)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                color: Colors.transparent,
                child: Row(children: [
                  if (step > 0)
                    OutlinedButton.icon(
                      onPressed: loading ? null : () => setState(() => step--),
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(80, 48),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  const Spacer(),
                  SizedBox(
                    width: 160,
                    child: LoadingButton(
                      loading: loading,
                      onPressed: step == 3 ? _calculate : _nextStep,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(step == 3 ? 'Get Quote' : 'Continue'),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),

          // ── Step 4 (Price Estimate) nav — Edit + Start Over ────────────
          if (step == 4)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                color: Colors.transparent,
                child: Row(children: [
                  // Edit details — go back to Step 3 (Finish & Options)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          loading ? null : () => setState(() => step = 3),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit Details'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Start over — reset wizard
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : _reset,
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: const Text('Start Over'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        side: const BorderSide(color: AppColors.cardBorder),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  // ── Step content (returned as list for ListView) ──────────────────────────
  List<Widget> _buildStepContent() {
    return [
      // Progress bar
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold.withValues(alpha: .4)),
          ),
          child: Text(
            'Step ${step + 1} of $_totalSteps',
            style: const TextStyle(
                color: AppColors.goldDark,
                fontSize: 11,
                fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (step + 1) / _totalSteps,
              minHeight: 6,
              backgroundColor: AppColors.cardBorder,
              color: AppColors.gold,
            ),
          ),
        ),
      ]),
      const SizedBox(height: 22),

      if (_isPromotionEligible)
        Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.success.withValues(alpha: .4)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: .2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.savings_outlined,
                    color: AppColors.success, size: 18),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Promotional Offer Applied!',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '₹200 cashback is for your first paid order from an eligible banner and is credited only after payment is captured.',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

      // Step 0 — Text Designer
      if (step == 0) ..._step0(),
      // Step 1 — Sign Type
      if (step == 1) ..._step1(),
      // Step 2 — Dimensions
      if (step == 2) ..._step2(),
      // Step 3 — Finish
      if (step == 3) ..._step3(),
      // Step 4 — Quote + Pay
      if (step == 4 && quote != null) ..._step4(),

      const SizedBox(height: 16),
    ];
  }

  // ── Step 0: Text Designer ─────────────────────────────────────────────────
  List<Widget> _step0() => [
        _heading('Design Your Sign Text', Icons.text_fields_rounded),
        if (_textDesign != null) ...[
          Container(
            key: const ValueKey('order-text-preview'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppColors.signPreviewBackground(_textDesign!.color),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: _textDesign!.color.withValues(alpha: .4)),
              boxShadow: [
                BoxShadow(
                    color: _textDesign!.color.withValues(alpha: .2),
                    blurRadius: 16)
              ],
            ),
            child: Center(
              child: Text(
                _textDesign!.text,
                style: TextStyle(
                  fontFamily: _textDesign!.fontFamily,
                  fontSize: 28,
                  color: _textDesign!.color,
                  shadows: [
                    Shadow(
                        color: _textDesign!.color.withValues(alpha: .8),
                        blurRadius: 12),
                    Shadow(
                        color: _textDesign!.color.withValues(alpha: .4),
                        blurRadius: 24),
                  ],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final r = await Navigator.push<SignBoardTextDesign>(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            TextDesignerScreen(initial: _textDesign)));
                if (r != null && mounted) setState(() => _textDesign = r);
              },
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit Text Design'),
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(children: [
              const Icon(Icons.text_fields_rounded,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              const Text('Add your sign board text',
                  style: TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const SizedBox(height: 6),
              const Text('Choose font, color and preview the neon effect',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final r = await Navigator.push<SignBoardTextDesign>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TextDesignerScreen()));
                  if (r != null && mounted) setState(() => _textDesign = r);
                },
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Open Text Designer'),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => setState(() => step = 1),
              child: const Text('Skip — Choose sign type instead',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ),
          ),
        ],
      ];

  // ── Step 1: Sign Type ─────────────────────────────────────────────────────
  List<Widget> _step1() => [
        _heading('Choose Sign Type', Icons.storefront_rounded),
        if (_optionsError != null)
          _loadErrorBanner(_optionsError!, _loadOrderOptions),
        if (_orderOptions == null &&
            !widget.api.mockMode &&
            _optionsError == null)
          const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _optionNames('signBoardTypes')
              .map((x) => ChoiceChip(
                    label: Text(x),
                    selected: type == x,
                    selectedColor: AppColors.gold.withValues(alpha: .2),
                    checkmarkColor: AppColors.gold,
                    onSelected: (_) => setState(() {
                      type = x;
                      _sideWalling = null;
                    }),
                  ))
              .toList(),
        ),
        if (([
          'Module LED Letters',
          'Channel LED Letters',
          'Bata Type LED Letters'
        ].contains(type))) ...[
          const SizedBox(height: 16),
          const Text(
            'Side Walling Color',
            style: TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w700,
                fontSize: 13),
          ),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final options = switch (type) {
              'Module LED Letters' => const ['Black', 'Grey'],
              'Channel LED Letters' => const [
                  'Gold',
                  'Silver',
                  'White',
                  'Black',
                  'Blue',
                  'Red'
                ],
              'Bata Type LED Letters' => const ['Gold', 'Rose Gold', 'Silver'],
              _ => const <String>[],
            };
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options
                  .map((opt) => ChoiceChip(
                        label: Text(opt),
                        selected: _sideWalling == opt,
                        selectedColor: AppColors.gold.withValues(alpha: .2),
                        checkmarkColor: AppColors.gold,
                        onSelected: (_) => setState(() => _sideWalling = opt),
                      ))
                  .toList(),
            );
          }),
        ],
      ];

  // ── Step 2: Dimensions ────────────────────────────────────────────────────
  List<Widget> _step2() => [
        _heading('Dimensions & Delivery', Icons.straighten_rounded),
        DropdownButtonFormField<String>(
          initialValue: _unitOptions.contains(unit) ? unit : null,
          decoration: const InputDecoration(labelText: 'Measurement unit'),
          dropdownColor: AppColors.white,
          items: _unitOptions
              .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => unit = value);
            _scheduleCalculation();
          },
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: TextField(
            controller: length,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
            ],
            style: const TextStyle(color: AppColors.charcoal),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.height_rounded),
            ).copyWith(labelText: 'Length ($unit)'),
          )),
          const SizedBox(width: 10),
          Expanded(
              child: TextField(
            controller: width,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
            ],
            style: const TextStyle(color: AppColors.charcoal),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.expand_rounded),
            ).copyWith(labelText: 'Width ($unit)'),
          )),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: quantity,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: AppColors.charcoal),
          decoration: const InputDecoration(
              labelText: 'Quantity',
              prefixIcon: Icon(Icons.format_list_numbered_rounded)),
        ),
        const SizedBox(height: 12),
        // ── Address field with autocomplete & saved addresses ───────────────
        AddressAutocompleteField(
          api: widget.api,
          initialAddress: address.text,
          onAddressSelected: (addr) {
            setState(() {
              _structuredDeliveryAddress = addr;
              address.text = addr.fullDisplayAddress;
            });
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: remarks,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Order notes (optional)',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _uploadingDesign ? null : _pickAndUploadDesign,
          icon: const Icon(Icons.attach_file),
          label: const Text('Add design or reference file'),
        ),
        if (_uploadingDesign) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _uploadProgress),
        ],
        for (var index = 0; index < _designFiles.length; index++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: Text(_designFiles[index]['name'] ?? 'Design file'),
            trailing: IconButton(
              tooltip: 'Remove file',
              onPressed: () => setState(() => _designFiles.removeAt(index)),
              icon: const Icon(Icons.close),
            ),
          ),
        if (_quoteError != null)
          _loadErrorBanner(_quoteError!, () => _calculate(advance: true)),
      ];

  // ── Step 3: Finish & Options ──────────────────────────────────────────────
  List<Widget> _step3() => [
        _heading('Finish & Options', Icons.palette_rounded),
        if (_optionsError != null)
          _loadErrorBanner(_optionsError!, _loadOrderOptions),
        DropdownButtonFormField<String>(
          initialValue:
              _optionNames('materials').contains(material) ? material : null,
          decoration: const InputDecoration(labelText: 'Material'),
          dropdownColor: AppColors.white,
          items: _optionNames('materials')
              .map((x) => DropdownMenuItem(value: x, child: Text(x)))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => material = v);
            _scheduleCalculation();
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue:
              _optionNames('lighting').contains(lighting) ? lighting : null,
          decoration: const InputDecoration(labelText: 'Lighting'),
          dropdownColor: AppColors.white,
          items: _optionNames('lighting')
              .map((x) => DropdownMenuItem(value: x, child: Text(x)))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => lighting = v);
            _scheduleCalculation();
          },
        ),
        const SizedBox(height: 12),
        if (lighting != 'No Lighting') ...[
          const SizedBox(height: 12),
          const Text(
            'LED Watt per Square Foot',
            style: TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w700,
                fontSize: 13),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _wattOptions.map((w) {
                final selected = _ledWatt == w;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(w),
                    selected: selected,
                    selectedColor: AppColors.gold.withValues(alpha: .2),
                    checkmarkColor: AppColors.gold,
                    onSelected: (_) {
                      setState(() => _ledWatt = w);
                      _scheduleCalculation();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final wattValue =
                double.tryParse(_ledWatt.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                    10.0;
            final l = double.tryParse(length.text) ?? 0;
            final ww = double.tryParse(width.text) ?? 0;
            final q = int.tryParse(quantity.text) ?? 1;
            final totalWatts = wattValue * l * ww * q;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withValues(alpha: .3)),
              ),
              child: Row(children: [
                const Icon(Icons.bolt_rounded, color: AppColors.gold, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Estimated power: ~${totalWatts.toStringAsFixed(0)}W',
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 12),
                  ),
                ),
              ]),
            );
          }),
        ],
        Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          child: Column(children: [
            SwitchListTile(
              value: installation,
              onChanged: (v) {
                setState(() => installation = v);
                _scheduleCalculation();
              },
              title: const Text('Installation required'),
            ),
            const Divider(height: 0, color: AppColors.cardBorder),
            SwitchListTile(
              value: transportation,
              onChanged: (v) {
                setState(() => transportation = v);
                _scheduleCalculation();
              },
              title: const Text('Transportation required'),
            ),
            for (final option in [
              ('Design', design, (value) => design = value),
              (
                'Electrical work',
                electricalWork,
                (value) => electricalWork = value
              ),
              (
                'Mounting structure',
                mountingStructure,
                (value) => mountingStructure = value
              ),
              ('Accessories', accessories, (value) => accessories = value),
              (
                'Customization',
                customization,
                (value) => customization = value
              ),
            ]) ...[
              const Divider(height: 0, color: AppColors.cardBorder),
              SwitchListTile(
                value: option.$2,
                title: Text(option.$1),
                onChanged: (value) {
                  setState(() => option.$3(value));
                  _scheduleCalculation();
                },
              ),
            ],
          ]),
        ),
      ];

  Widget _loadErrorBanner(String message, Future<void> Function() retry) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: AppColors.danger.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(10),
          child: ListTile(
            leading:
                const Icon(Icons.cloud_off_outlined, color: AppColors.danger),
            title: const Text('Could not load ordering options'),
            subtitle:
                Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: 'Retry',
              onPressed: retry,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ),
      );

  double _quotePrice(String key) => (quote?[key] as num?)?.toDouble() ?? 0;

  Future<void> _showPriceBreakdown() => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.white,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (context) {
          const rows = <(String, String)>[
            ('Sign Board', 'productCost'),
            ('Material', 'materialCost'),
            ('Lighting', 'lightingCost'),
            ('LED Watt', 'wattCost'),
            ('Installation', 'installation'),
            ('Transportation', 'transportation'),
            ('Design', 'design'),
            ('Electrical work', 'electricalWork'),
            ('Mounting structure', 'mountingStructure'),
            ('Accessories', 'accessories'),
            ('Customization', 'customization'),
            ('Discount', 'discount'),
            ('GST', 'gst'),
          ];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Price Breakdown',
                      style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  if (quote?['area'] != null)
                    _summaryRow(
                      'Area',
                      '${quote!['area']} ${quote?['areaUnit'] ?? ''}',
                      Icons.square_foot,
                    ),
                  for (final (label, key) in rows)
                    if (quote?[key] is num)
                      _summaryRow(label, '', Icons.receipt_outlined,
                          price: _quotePrice(key)),
                  const Divider(),
                  _summaryRow('Estimated total', '', Icons.calculate_outlined,
                      price: _quotePrice('estimatedPrice')),
                ],
              ),
            ),
          );
        },
      );

  Widget _summaryRow(
    String label,
    String value,
    IconData icon, {
    double? price,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
                if (value.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          if (price != null) ...[
            const SizedBox(width: 8),
            Text(
              price == 0 ? 'Free' : money(price),
              style: TextStyle(
                color: price == 0 ? AppColors.success : AppColors.textBody,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryChip(
    String value,
    String label,
    IconData icon, {
    Color? color,
    double? price,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 88),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color ?? AppColors.gold, size: 15),
            const SizedBox(width: 5),
            Text(label,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ]),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          if (price != null) ...[
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: price == 0
                    ? AppColors.success.withValues(alpha: .12)
                    : AppColors.gold.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                price == 0 ? 'Free' : money(price),
                style: TextStyle(
                  color: price == 0 ? AppColors.success : AppColors.goldDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Step 4: Quote + Payment ───────────────────────────────────────────────
  List<Widget> _step4() {
    final total = _quotePrice('estimatedPrice');
    final gst = quote?['gst'] is num ? _quotePrice('gst') : null;
    final subtotal = quote?['subtotal'] is num
        ? _quotePrice('subtotal')
        : quote?['taxableAmount'] is num
            ? _quotePrice('taxableAmount')
            : null;
    final deliveryAddress =
        address.text.trim().isEmpty ? 'Not provided' : address.text.trim();

    return [
      _heading('Price Estimate & Payment', Icons.calculate_rounded),
      if (_recalculating)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: LinearProgressIndicator(color: AppColors.gold),
        ),
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
            const Row(children: [
              Icon(Icons.receipt_long_rounded, color: AppColors.gold, size: 20),
              SizedBox(width: 8),
              Text('Order Summary',
                  style: TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ]),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _summaryChip('${length.text} $unit', 'Length', Icons.height),
                _summaryChip('${width.text} $unit', 'Width', Icons.expand),
                _summaryChip(quantity.text, 'Quantity',
                    Icons.format_list_numbered_rounded),
              ],
            ),
            _summaryRow('Sign Board', type, Icons.signpost_outlined,
                price: _quotePrice('productCost')),
            const Divider(height: 1, color: AppColors.cardBorder),
            _summaryRow('Material', material, Icons.layers_outlined,
                price: _quotePrice('materialCost')),
            _summaryRow('Lighting', lighting, Icons.lightbulb_outline_rounded,
                price: _quotePrice('lightingCost')),
            if (lighting != 'No Lighting')
              _summaryRow('LED Watt', _ledWatt, Icons.bolt_rounded,
                  price: _quotePrice('wattCost')),
            if (_sideWalling != null && _sideWalling!.isNotEmpty)
              _summaryRow(
                  'Side Walling', _sideWalling!, Icons.view_sidebar_outlined),
            const SizedBox(height: 8),
            const Text('Delivery Address',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.location_on_outlined,
                  color: AppColors.gold, size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Text(deliveryAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textBody, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _summaryChip(
                  installation ? 'Included' : 'Not selected',
                  'Installation',
                  Icons.handyman_outlined,
                  color: installation ? AppColors.success : AppColors.textMuted,
                  price: installation ? _quotePrice('installation') : null,
                ),
                _summaryChip(
                  transportation ? 'Included' : 'Not selected',
                  'Transport',
                  Icons.local_shipping_outlined,
                  color:
                      transportation ? AppColors.success : AppColors.textMuted,
                  price: transportation ? _quotePrice('transportation') : null,
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: AppColors.cardBorder),
            ),
            if (quote?['area'] != null)
              _summaryRow(
                'Measured area',
                '${quote!['area']} ${quote?['areaUnit'] ?? ''}',
                Icons.square_foot,
              ),
            if (subtotal != null)
              _summaryRow('Taxable amount', '', Icons.receipt_outlined,
                  price: subtotal),
            if (gst != null)
              _summaryRow('GST', '', Icons.percent_rounded, price: gst),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.gold.withValues(alpha: .35)),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(
                      _orderOptions?['priceLabel']?.toString() ??
                          'Estimated Total (incl. GST)',
                      style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ),
                Text(money(total),
                    style: const TextStyle(
                        color: AppColors.goldDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
              ]),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _showPriceBreakdown,
                icon: const Icon(Icons.expand_more),
                label: const Text('Price Breakdown'),
              ),
            ),
            if ((_orderOptions?['priceNotice'] ?? quote?['notice']) != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  (_orderOptions?['priceNotice'] ?? quote?['notice'])
                      .toString(),
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            if (_quoteError != null)
              _loadErrorBanner(_quoteError!, () => _calculate(advance: false)),
            if (_isPromotionEligible) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: .35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded,
                        color: AppColors.success, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _cashbackStatus == 'not_eligible_repeat_user'
                            ? 'Cashback is not available because a previous paid order has already qualified.'
                            : '₹200 cashback applies only to your first paid order from an eligible banner and is credited after payment is captured.',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.softGray,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: _walletLoading
                  ? const LinearProgressIndicator(color: AppColors.gold)
                  : _walletError != null
                      ? Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Wallet balance unavailable: $_walletError',
                                style:
                                    const TextStyle(color: AppColors.textLight),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: _loadWallet,
                              child: const Text('Retry'),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _useWallet && _walletBalance > 0,
                              activeColor: AppColors.gold,
                              checkColor: AppColors.navyDeep,
                              onChanged: _walletBalance <= 0 || _orderSubmitted
                                  ? null
                                  : (value) => setState(
                                      () => _useWallet = value ?? false),
                              title: const Text(
                                'Use SignFix Wallet',
                                style: TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                _walletBalance <= 0
                                    ? 'Available balance: ₹0.00 (No balance to apply)'
                                    : 'Available balance: ${money(_walletBalance)}'
                                        '${_useWallet ? ' (Applying ${money(_walletAppliedTo(total))})' : ''}',
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 12),
                              ),
                            ),
                            if (_useWallet && _walletBalance > 0) ...[
                              const Divider(color: AppColors.cardBorder),
                              _summaryRow(
                                'Wallet balance applied',
                                '',
                                Icons.account_balance_wallet_outlined,
                                price: -_walletAppliedTo(total),
                              ),
                              _summaryRow(
                                'Remaining payable',
                                '',
                                Icons.payments_outlined,
                                price: _amountToPay(total),
                              ),
                              if (_amountToPay(total) <= 0)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.success
                                        .withValues(alpha: .15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.success
                                          .withValues(alpha: .4),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.check_circle_outline,
                                          color: AppColors.success, size: 16),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '100% of order payable covered by your wallet balance!',
                                          style: TextStyle(
                                            color: AppColors.success,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),

      // ── Payment Type Selector ──────────────────────────────────────────
      const SizedBox(height: 20),
      const Text(
        'Payment Type',
        style: TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.w700,
            fontSize: 14),
      ),
      const SizedBox(height: 10),
      Builder(builder: (context) {
        final total = _checkoutPayableTotal;
        final advance = total * 0.25;
        return Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _paymentType = 'full'),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _paymentType == 'full'
                      ? AppColors.gold.withValues(alpha: .15)
                      : AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _paymentType == 'full'
                        ? AppColors.gold
                        : AppColors.cardBorder,
                    width: _paymentType == 'full' ? 2 : 1,
                  ),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Full Payment',
                        style: TextStyle(
                          color: _paymentType == 'full'
                              ? AppColors.gold
                              : AppColors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        money(total),
                        style: TextStyle(
                          color: _paymentType == 'full'
                              ? AppColors.gold
                              : AppColors.textMuted,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Pay entire amount',
                        style:
                            TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ]),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _paymentType = 'advance'),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _paymentType == 'advance'
                      ? AppColors.gold.withValues(alpha: .15)
                      : AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _paymentType == 'advance'
                        ? AppColors.gold
                        : AppColors.cardBorder,
                    width: _paymentType == 'advance' ? 2 : 1,
                  ),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Advance (25%)',
                        style: TextStyle(
                          color: _paymentType == 'advance'
                              ? AppColors.gold
                              : AppColors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        money(advance),
                        style: TextStyle(
                          color: _paymentType == 'advance'
                              ? AppColors.gold
                              : AppColors.textMuted,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Pay 25% now',
                        style:
                            TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ]),
              ),
            ),
          ),
        ]);
      }),

      const SizedBox(height: 20),

      // ── Processing state ───────────────────────────────────────────────
      if (_payProcessing)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: AppColors.gold),
            SizedBox(height: 14),
            Text('Processing payment…',
                style: TextStyle(color: AppColors.textLight)),
          ])),
        ),

      // ── Error / pending banner ─────────────────────────────────────────
      if (_payError != null && !_payProcessing)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (_payPending ? AppColors.warning : AppColors.danger)
                .withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _payPending ? AppColors.warning : AppColors.danger,
            ),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(
              _payPending
                  ? Icons.hourglass_top_rounded
                  : Icons.error_outline_rounded,
              color: _payPending ? AppColors.warning : AppColors.danger,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _payError!,
                style: TextStyle(
                  color: _payPending ? AppColors.warning : AppColors.danger,
                  fontSize: 13,
                ),
              ),
            ),
          ]),
        ),

      if (!_payProcessing && !_paySuccess && _checkoutPayAmount <= 0)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withValues(alpha: .5)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppColors.success),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your wallet covers the payable amount for this order.',
                  style: TextStyle(color: AppColors.textLight),
                ),
              ),
            ],
          ),
        ),

      // ── Payment method selector ────────────────────────────────────────
      if (!_payProcessing && !_paySuccess && _checkoutPayAmount > 0) ...[
        const Text('Select a Payment Method',
            style: TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
        const SizedBox(height: 6),
        const Text(
          'Choose the available payment method in Razorpay secure checkout.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _WizardPayMethod(Icons.account_balance_wallet_outlined, 'UPI / GPay',
              AppColors.gold,
              selected: _payMethod == 'upi',
              onTap: () => setState(() {
                    _payMethod = 'upi';
                    _payError = null;
                    _upiError = null;
                  })),
          const SizedBox(width: 10),
          _WizardPayMethod(
              Icons.credit_card_outlined, 'Credit / Debit', AppColors.info,
              selected: _payMethod == 'card',
              onTap: () => setState(() {
                    _payMethod = 'card';
                    _payError = null;
                    _upiError = null;
                  })),
          const SizedBox(width: 10),
          _WizardPayMethod(
              Icons.account_balance_outlined, 'Net Banking', AppColors.success,
              selected: _payMethod == 'netbanking',
              onTap: () => setState(() {
                    _payMethod = 'netbanking';
                    _payError = null;
                    _upiError = null;
                  })),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _WizardPayMethod(
              Icons.phone_android_outlined, 'Wallets', AppColors.warning,
              selected: _payMethod == 'wallet',
              onTap: () => setState(() {
                    _payMethod = 'wallet';
                    _payError = null;
                    _upiError = null;
                  })),
          const SizedBox(width: 10),
          _WizardPayMethod(
              Icons.currency_rupee_outlined, 'EMI', AppColors.textLight,
              selected: _payMethod == 'emi',
              onTap: () => setState(() {
                    _payMethod = 'emi';
                    _payError = null;
                    _upiError = null;
                  })),
        ]),
        const SizedBox(height: 16),
        // Dynamic fields based on selected method
        if (_payMethod == 'upi') ..._buildUpiFields(),
        if (_payMethod == 'card') ..._buildCardFields(),
        if (_payMethod == 'netbanking') ..._buildNetBankingFields(),
        if (_payMethod == 'wallet') ..._buildWalletFields(),
        if (_payMethod == 'emi') ..._buildEmiFields(),
        const SizedBox(height: 20),
        // Security badge
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.softGray,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: const Row(children: [
            Icon(Icons.lock_rounded, color: AppColors.success, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '100% Secure · Powered by Razorpay · Card details, bank credentials and OTP are entered only in Razorpay Checkout.',
                style: TextStyle(color: AppColors.textLight, fontSize: 12),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        // "Pay & Submit Order" button
        GestureDetector(
          onTap: (_payProcessing || _payLaunched || !_quoteIsCurrent)
              ? null
              : _payAndSubmit,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.gold, AppColors.goldDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: .35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.lock_rounded,
                  color: AppColors.navyDeep, size: 18),
              const SizedBox(width: 10),
              Text(
                _payProcessing
                    ? 'Processing...'
                    : _orderSubmitted
                        ? 'Retry Payment'
                        : _checkoutPayAmount <= 0
                            ? 'Place Order with Wallet'
                            : 'Submit & Pay ${money(_checkoutPayAmount)}',
                style: const TextStyle(
                  color: AppColors.navyDeep,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Card, bank, wallet details and OTP are entered securely in Razorpay Checkout.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
        if (_orderSubmitted) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              _reset();
              widget.onOrderSubmitted?.call();
            },
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: Text('Order $_submittedOrderNo created · View in Orders'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.gold,
              side: const BorderSide(color: AppColors.gold),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ],

      // ── Success + submitting state ─────────────────────────────────────
      if (_paySuccess && _payProcessing)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: AppColors.success),
            SizedBox(height: 14),
            Text('Payment confirmed! Submitting your order…',
                style: TextStyle(color: AppColors.success)),
          ])),
        ),
    ];
  }

  // ── UPI fields ─────────────────────────────────────────────────────────────
  List<Widget> _buildUpiFields() => [
        TextField(
          controller: _upiController,
          keyboardType: TextInputType.text,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          style: const TextStyle(color: AppColors.charcoal),
          decoration: InputDecoration(
            labelText: 'UPI ID (optional)',
            hintText: 'e.g. username@bank',
            prefixIcon:
                const Icon(Icons.alternate_email, color: AppColors.gold),
            errorText: _upiError,
          ),
          onChanged: (_) {
            if (_upiError != null) setState(() => _upiError = null);
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: const Row(children: [
            Icon(Icons.qr_code_2_rounded, color: AppColors.gold, size: 48),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pay via QR Code',
                      style: TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  SizedBox(height: 4),
                  Text('Scan using any UPI app (GPay, PhonePe, Paytm)',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ]),
        ),
      ];

  // Card, bank credentials, and OTP are entered only in Razorpay Checkout.
  List<Widget> _buildCardFields() => [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: const Row(children: [
            Icon(Icons.lock_outline_rounded,
                color: AppColors.success, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Enter your card details and any verification code in the secure Razorpay checkout screen.',
                style: TextStyle(color: AppColors.textLight, fontSize: 12),
              ),
            ),
          ]),
        ),
      ];

  // ── Net Banking fields ─────────────────────────────────────────────────────
  List<Widget> _buildNetBankingFields() => [
        DropdownButtonFormField<String>(
          initialValue: _selectedBank,
          decoration: const InputDecoration(
            labelText: 'Select Bank',
            prefixIcon:
                Icon(Icons.account_balance_outlined, color: AppColors.success),
          ),
          dropdownColor: AppColors.white,
          style: const TextStyle(color: AppColors.charcoal),
          items: const [
            'SBI',
            'HDFC Bank',
            'ICICI Bank',
            'Axis Bank',
            'Kotak Mahindra',
            'Punjab National Bank',
            'Bank of Baroda',
            'Canara Bank',
            'Yes Bank',
            'IDBI Bank',
          ].map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
          onChanged: (v) => setState(() {
            _selectedBank = v;
            if (_payError != null) _payError = null;
          }),
        ),
      ];

  // ── Wallet fields ──────────────────────────────────────────────────────────
  List<Widget> _buildWalletFields() {
    final wallets = [
      const _WalletOption(
          'Paytm', Icons.account_balance_wallet_rounded, AppColors.info),
      const _WalletOption(
          'PhonePe', Icons.phone_android_rounded, AppColors.navy),
      const _WalletOption('Mobikwik', Icons.wallet_rounded, AppColors.warning),
    ];
    return [
      // Use fixed-height containers instead of Expanded inside ListView
      SizedBox(
        height: 90,
        child: Row(
          children: wallets.asMap().entries.map((entry) {
            final idx = entry.key;
            final w = entry.value;
            final selected = _selectedWallet == w.name;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedWallet = w.name;
                  if (_payError != null) _payError = null;
                }),
                child: Container(
                  margin:
                      EdgeInsets.only(right: idx < wallets.length - 1 ? 10 : 0),
                  decoration: BoxDecoration(
                    color: selected
                        ? w.color.withValues(alpha: .15)
                        : AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppColors.gold : AppColors.cardBorder,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(w.icon,
                          color: selected ? w.color : AppColors.textMuted,
                          size: 28),
                      const SizedBox(height: 6),
                      Text(
                        w.name,
                        style: TextStyle(
                          color:
                              selected ? AppColors.white : AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ];
  }

  // ── EMI fields ─────────────────────────────────────────────────────────────
  List<Widget> _buildEmiFields() {
    final estimatedPrice = _checkoutPayableTotal;
    final total =
        _paymentType == 'advance' ? estimatedPrice * 0.25 : estimatedPrice;
    final plans = [3, 6, 9, 12];
    return [
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: plans.map((months) {
          final monthly = total / months;
          final selected = _emiMonths == months;
          return GestureDetector(
            onTap: () => setState(() {
              _emiMonths = months;
              if (_payError != null) _payError = null;
            }),
            child: Container(
              width: (MediaQuery.of(context).size.width - 36 - 10) / 2,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.gold.withValues(alpha: .15)
                    : AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.gold : AppColors.cardBorder,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$months months',
                      style: TextStyle(
                        color: selected ? AppColors.gold : AppColors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${money(monthly)}/month',
                      style: TextStyle(
                        color: selected ? AppColors.gold : AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${money(total)} total',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ]),
            ),
          );
        }).toList(),
      ),
    ];
  }

  // ── Heading widget ────────────────────────────────────────────────────────
  Widget _heading(String text, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.gold, size: 20),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy)),
          ),
        ]),
      );
}

// ── Payment method card widget (Step 4 only) ──────────────────────────────
class _WizardPayMethod extends StatelessWidget {
  const _WizardPayMethod(this.icon, this.label, this.color,
      {this.selected = false, this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.softGray : AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppColors.gold : AppColors.cardBorder,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 5),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (selected)
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
            ]),
          ),
        ),
      );
}

class _WalletOption {
  const _WalletOption(this.name, this.icon, this.color);
  final String name;
  final IconData icon;
  final Color color;
}
