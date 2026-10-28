import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PaymentScreen — Full Razorpay checkout with dark SignFix theme
// ────────────────────────────────────────────────────────────────────────────

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.api,
    required this.orderId,
    required this.quotationNo,
    required this.paymentType,
    required this.amount,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.description,
    required this.onSuccess,
    required this.onFailure,
  });

  final ApiClient api;
  final String orderId;
  final String quotationNo;
  final String paymentType;
  final double amount; // INR (Rupees)
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String description;
  final void Function(String paymentId) onSuccess;
  final void Function(String reason) onFailure;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final Razorpay _razorpay;
  bool _launched = false;
  bool _processing = false;
  String? _resultMessage;
  bool _isSuccess = false;
  bool _isPending = false;
  bool _canRetry = true;
  String? _paymentIntentId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _launch({String? upiId}) async {
    setState(() {
      _launched = true;
      _processing = true;
      _isPending = false;
      _paymentIntentId = null;
    });

    try {
      // 1. Backend se payment intent mango
      final intent = await widget.api.createPaymentIntent({
        'quotationNo': widget.quotationNo,
        'type': widget.paymentType,
        'amount': widget.amount,
        'idempotencyKey':
            '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32).toRadixString(16)}',
      });

      final paymentIntentId = intent['id']?.toString();
      final checkoutValue = intent['checkout'];

      if (paymentIntentId == null ||
          paymentIntentId.isEmpty ||
          checkoutValue is! Map) {
        throw Exception('Server ne valid payment intent nahi bheja.');
      }

      final checkout = Map<String, dynamic>.from(checkoutValue);
      final keyId = checkout['keyId']?.toString();
      final providerOrderId = checkout['orderId']?.toString();

      // Amount ko safe tarike se handle karna (Int ya Double dono handle honge)
      final dynamic rawAmount = checkout['amount'];
      final int amountInPaise;
      if (rawAmount is int) {
        amountInPaise = rawAmount;
      } else if (rawAmount is double) {
        amountInPaise = rawAmount.round();
      } else {
        throw Exception('Backend ne invalid amount format bheja hai.');
      }

      final currency = checkout['currency']?.toString() ?? 'INR';

      // 2. STRICT CHECKS (Yahan se pata chalega masla kya hai)
      final effectiveKey = (keyId != null && keyId.startsWith('rzp_'))
          ? keyId
          : 'rzp_live_TZRwgnPCEkDeu4';

      if (amountInPaise <= 0) {
        throw Exception('Amount 0 ya negative hai: $amountInPaise');
      }

      _paymentIntentId = paymentIntentId;

      debugPrint('🔑 Key ID: $effectiveKey');
      debugPrint(' Razorpay Order ID: $providerOrderId');
      debugPrint('💰 Amount Backend se (Paise): $amountInPaise');
      debugPrint('💵 Rupees mein: ₹${amountInPaise / 100}');

      // 4. Razorpay Open Karein
      final options = <String, dynamic>{
        'key': effectiveKey,
        'amount': amountInPaise,
        'currency': currency,
        'name': 'SignFix',
        'description': widget.description,
        if (providerOrderId != null && providerOrderId.startsWith('order_'))
          'order_id': providerOrderId,
        'prefill': {
          'name': widget.customerName,
          'email': widget.customerEmail,
          'contact': widget.customerPhone,
        },
        'theme': {
          'color': '#F5A800',
        },
      };

      debugPrint('📋 Razorpay Options: $options');

      try {
        _razorpay.open(options);
        debugPrint('✅ _razorpay.open() called successfully');
      } catch (sdkError) {
        debugPrint('❌ RAZORPAY SDK ERROR: $sdkError');
        rethrow;
      }
    } catch (e) {
      debugPrint('❌ PAYMENT SETUP ERROR: $e');
      if (!mounted) return;
      setState(() {
        _processing = false;
        // User ko exact error dikhayein taaki wo samajh sake
        _resultMessage = 'Payment Setup Failed:\n$e';
        _isSuccess = false;
        _isPending = false;
        _canRetry = true;
      });
    }
  }

  void _onSuccess(PaymentSuccessResponse resp) {
    unawaited(_verifyAndComplete(resp));
  }

  Future<void> _verifyAndComplete(PaymentSuccessResponse resp) async {
    final paymentIntentId = _paymentIntentId;
    final paymentId = resp.paymentId;
    final providerOrderId = resp.orderId;
    final signature = resp.signature;

    if (paymentId == null || paymentId.isEmpty) {
      _showPending(
        'Razorpay did not return a payment ID. Please contact support.',
      );
      return;
    }

    setState(() {
      _processing = true;
      _resultMessage = null;
      _canRetry = false;
    });

    if (paymentIntentId != null &&
        providerOrderId != null &&
        signature != null) {
      try {
        final verified = await widget.api.verifyPayment(paymentIntentId, {
          'razorpayPaymentId': paymentId,
          'razorpayOrderId': providerOrderId,
          'razorpaySignature': signature,
        });
        debugPrint(
            'Quotation payment verification result: status=${verified['status']}');
        final status = (verified['status'] ?? '').toString().toLowerCase();
        if (status == 'captured' || status == 'authorized') {
          if (!mounted) return;
          setState(() {
            _processing = false;
            _isSuccess = true;
            _isPending = false;
            _resultMessage = paymentId;
          });
          widget.onSuccess(paymentId);
          return;
        } else if (status == 'failed') {
          throw Exception('Payment was rejected or failed at provider.');
        } else {
          _showPending(
              'Payment is pending gateway confirmation. Current status: $status');
          return;
        }
      } catch (e) {
        debugPrint('Verification endpoint error: $e');
        _showPending(
            'Payment was received by gateway but could not be verified by backend: $e. Please do not pay again.');
        return;
      }
    } else {
      _showPending(
          'Payment session missing signature or intent. Reference: $paymentId');
      return;
    }
  }

  void _showPending(String message) {
    if (!mounted) return;
    setState(() {
      _processing = false;
      _isSuccess = false;
      _isPending = true;
      _canRetry = false;
      _resultMessage = message;
    });
  }

  void _onError(PaymentFailureResponse resp) {
    unawaited(_reportFailure(resp));
  }

  String _friendlyError(PaymentFailureResponse resp) {
    final code = resp.code ?? 0;
    final raw = (resp.message ?? '').toLowerCase();

    if (code == Razorpay.PAYMENT_CANCELLED ||
        raw.contains('cancel') ||
        raw.contains('dismiss')) {
      return 'You cancelled the payment. You can try again whenever you\'re ready.';
    }
    if (code == Razorpay.NETWORK_ERROR ||
        raw.contains('network') ||
        raw.contains('internet') ||
        raw.contains('connect') ||
        raw.contains('timeout')) {
      return 'Unable to connect to the payment service. Please check your internet connection and try again.';
    }
    if (raw.contains('insufficient') ||
        raw.contains('low balance') ||
        raw.contains('not enough')) {
      return 'Your account has insufficient funds. Please use another payment method.';
    }
    if (raw.contains('declined') ||
        raw.contains('do not honour') ||
        raw.contains('card blocked')) {
      return 'Your payment was declined by the bank. Please try another payment method.';
    }

    final cleanMsg = resp.message
            ?.replaceAll(RegExp(r'Exception:?\s*'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim() ??
        '';
    if (cleanMsg.isNotEmpty && cleanMsg.length < 120) return cleanMsg;

    return 'Payment could not be completed. Please try a different payment method or contact support.';
  }

  Future<void> _reportFailure(PaymentFailureResponse resp) async {
    final paymentIntentId = _paymentIntentId;
    final message = _friendlyError(resp);

    if (paymentIntentId != null) {
      try {
        await widget.api.reportPaymentFailure(paymentIntentId, {
          if (resp.code != null) 'code': resp.code.toString(),
          'description': resp.message ?? 'Razorpay payment failed',
          'source': 'razorpay',
          'step': 'checkout',
        });
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _processing = false;
      _isSuccess = false;
      _isPending = false;
      _canRetry = true;
      _resultMessage = message;
    });
    widget.onFailure(message);
  }

  void _onWallet(ExternalWalletResponse resp) {
    _showPending(
      'The ${resp.walletName} payment was started, but has not been confirmed by SignFix yet. Check your payment status before trying again.',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.navyDeep,
        appBar: AppBar(
          backgroundColor: AppColors.navyDark,
          title: const Row(children: [
            Icon(Icons.payment_rounded, color: AppColors.gold, size: 22),
            SizedBox(width: 8),
            Text('Secure Payment',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.white)),
          ]),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.gold),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _resultMessage != null
            ? _ResultView(
                isSuccess: _isSuccess,
                isPending: _isPending,
                message: _resultMessage!,
                orderId: widget.orderId,
                onDone: () => Navigator.pop(context, _isSuccess),
                onRetry: !_canRetry || _isSuccess
                    ? null
                    : () => setState(() {
                          _resultMessage = null;
                          _launched = false;
                          _isPending = false;
                          _paymentIntentId = null;
                        }),
              )
            : _processing
                ? const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(color: AppColors.gold),
                      SizedBox(height: 16),
                      Text('Opening payment gateway…',
                          style: TextStyle(color: AppColors.textLight)),
                    ]),
                  )
                : _PaymentSummary(
                    orderId: widget.orderId,
                    paymentType: widget.paymentType,
                    amount: widget.amount,
                    description: widget.description,
                    customerName: widget.customerName,
                    onPay: (upiId) => _launch(upiId: upiId),
                    launched: _launched,
                  ),
      );
}

// ── Payment Summary Page ─────────────────────────────────────────────────────
class _PaymentSummary extends StatefulWidget {
  const _PaymentSummary({
    required this.orderId,
    required this.paymentType,
    required this.amount,
    required this.description,
    required this.customerName,
    required this.onPay,
    required this.launched,
  });
  final String orderId, paymentType, description, customerName;
  final double amount;
  final void Function(String? upiId) onPay;
  final bool launched;

  @override
  State<_PaymentSummary> createState() => _PaymentSummaryState();
}

class _PaymentSummaryState extends State<_PaymentSummary> {
  String _selectedMethod = 'upi';
  final TextEditingController _upiController = TextEditingController();
  String? _upiError;

  static final _upiRegex = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,}$');

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  void _select(String id) => setState(() => _selectedMethod = id);

  void _pay() {
    if (widget.launched) return;
    final upiId = _upiController.text.trim();
    if (_selectedMethod == 'upi' &&
        upiId.isNotEmpty &&
        !_upiRegex.hasMatch(upiId)) {
      setState(() => _upiError = 'Enter a valid UPI ID (e.g. username@bank)');
      return;
    }
    if (_upiError != null) setState(() => _upiError = null);
    widget.onPay(_selectedMethod == 'upi' ? upiId : null);
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navy, AppColors.navyDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.gold.withValues(alpha: .3)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: AppColors.gold, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Approved quotation',
                          style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      Text(widget.orderId,
                          style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ])),
              ]),
              const SizedBox(height: 16),
              Divider(color: AppColors.navyLight.withValues(alpha: .6)),
              const SizedBox(height: 12),
              _SummaryRow('Customer', widget.customerName),
              _SummaryRow(
                  'Payment option',
                  widget.paymentType == 'advance'
                      ? '25% advance'
                      : 'Full balance'),
              _SummaryRow('Description', widget.description),
              const SizedBox(height: 12),
              Divider(color: AppColors.navyLight.withValues(alpha: .6)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Final quotation amount',
                    style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text(
                  '₹${widget.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 26,
                      fontWeight: FontWeight.w900),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 24),
          const Text('Select a Payment Method',
              style: TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          const SizedBox(height: 6),
          const Text(
              'Choose the available payment method in Razorpay secure checkout.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 12),
          Row(children: [
            _PayMethod(Icons.account_balance_wallet_outlined, 'UPI / GPay',
                AppColors.gold,
                selected: _selectedMethod == 'upi',
                onTap: () => _select('upi')),
            const SizedBox(width: 10),
            _PayMethod(
                Icons.credit_card_outlined, 'Credit / Debit', AppColors.info,
                selected: _selectedMethod == 'card',
                onTap: () => _select('card')),
            const SizedBox(width: 10),
            _PayMethod(Icons.account_balance_outlined, 'Net Banking',
                AppColors.success,
                selected: _selectedMethod == 'netbanking',
                onTap: () => _select('netbanking')),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _PayMethod(
                Icons.phone_android_outlined, 'Wallets', AppColors.warning,
                selected: _selectedMethod == 'wallet',
                onTap: () => _select('wallet')),
            const SizedBox(width: 10),
            _PayMethod(
                Icons.currency_rupee_outlined, 'EMI', AppColors.textLight,
                selected: _selectedMethod == 'emi',
                onTap: () => _select('emi')),
          ]),
          if (_selectedMethod == 'upi') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _upiController,
              keyboardType: TextInputType.text,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'UPI ID',
                hintText: 'e.g. username@bank',
                prefixIcon:
                    const Icon(Icons.alternate_email, color: AppColors.gold),
                errorText: _upiError,
              ),
              onChanged: (_) {
                if (_upiError != null) setState(() => _upiError = null);
              },
            ),
          ],
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.navyDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.navyLight),
            ),
            child: const Row(children: [
              Icon(Icons.lock_rounded, color: AppColors.success, size: 18),
              SizedBox(width: 10),
              Expanded(
                  child: Text(
                '100% Secure • Powered by Razorpay • PCI DSS Compliant',
                style: TextStyle(color: AppColors.textLight, fontSize: 12),
              )),
            ]),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: widget.launched ? null : _pay,
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
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.lock_rounded,
                    color: AppColors.navyDeep, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Continue to Razorpay · ₹${widget.amount.toStringAsFixed(0)}',
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
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'You will be redirected to Razorpay secure checkout',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
}

// ── Result View ───────────────────────────────────────────────────────────────
class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.isSuccess,
    required this.isPending,
    required this.message,
    required this.orderId,
    required this.onDone,
    required this.onRetry,
  });
  final bool isSuccess;
  final bool isPending;
  final String message, orderId;
  final VoidCallback onDone;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final statusColor = isSuccess
        ? AppColors.success
        : (isPending ? AppColors.warning : AppColors.danger);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .12),
              shape: BoxShape.circle,
              border: Border.all(color: statusColor, width: 2),
            ),
            child: Icon(
              isSuccess
                  ? Icons.check_circle_rounded
                  : (isPending
                      ? Icons.hourglass_top_rounded
                      : Icons.cancel_rounded),
              color: statusColor,
              size: 52,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            isSuccess
                ? 'Payment Successful!'
                : (isPending ? 'Payment Status Pending' : 'Payment Failed'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.navyDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.navyLight),
            ),
            child: Text(
              isSuccess ? 'Payment ID: $message' : message,
              style: const TextStyle(color: AppColors.textLight, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          if (isSuccess) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.success.withValues(alpha: .3)),
              ),
              child: Text(
                'Payment recorded for order $orderId',
                style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onDone,
              child: Text(isSuccess ? 'View My Orders' : 'Back to Order'),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try Again'),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          Flexible(
              child: Text(value,
                  style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.end)),
        ]),
      );
}

class _PayMethod extends StatelessWidget {
  const _PayMethod(this.icon, this.label, this.color,
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
              color: selected ? AppColors.navyMid : AppColors.navyDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppColors.gold : AppColors.navyLight,
                width: selected ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(height: 5),
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center),
                ]),
                if (selected)
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(Icons.check_circle,
                        color: AppColors.gold, size: 16),
                  ),
              ],
            ),
          ),
        ),
      );
}
