import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.field, this.code});
  final String message;
  final int? statusCode;
  final String? field;
  final String? code;
  @override
  String toString() => message;
}

// ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
//  MOCK DATA ΓÇö demo mode (no backend needed)
// ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
const _mockDelay = Duration(milliseconds: 700);

final _mockProfile = <String, dynamic>{
  'id': 'CUST-001',
  'name': 'Demo Customer',
  'email': 'customer@signfix.in',
  'phone': '03001234567',
  'address': 'Shop 12, Main Market, Lahore',
  'memberSince': '2025-01-15',
  'totalOrders': 4,
  'totalServices': 3,
  'profilePhotoPath': null, // local file path ΓÇö set when user picks image
};

final _mockOrders = <Map<String, dynamic>>[
  {
    'id': 'ORD-1001',
    'status': 'in_production',
    'product': 'LED Sign Board',
    'material': 'Acrylic',
    'lighting': 'LED',
    'length': 10,
    'width': 3,
    'quantity': 1,
    'installation': true,
    'transportation': true,
    'address': 'Shop 12, Main Market, Lahore',
    'estimatedPrice': 18500,
    'gst': 2838,
    'createdAt': '2026-09-20',
    'updatedAt': '2026-09-22',
    'statusHistory': [
      {'status': 'pending', 'time': '2026-09-20 10:30'},
      {'status': 'reviewed', 'time': '2026-09-21 09:15'},
      {'status': 'in_production', 'time': '2026-09-22 11:00'},
    ],
    'notes': 'Customer requested matte finish on edges.',
  },
  {
    'id': 'ORD-1002',
    'status': 'delivered',
    'product': 'Flex Sign Board',
    'material': 'Flex',
    'lighting': 'No Lighting',
    'length': 8,
    'width': 4,
    'quantity': 2,
    'installation': false,
    'transportation': true,
    'address': 'Plot 5, Gulberg III, Lahore',
    'estimatedPrice': 11200,
    'gst': 1717,
    'createdAt': '2026-08-10',
    'updatedAt': '2026-08-18',
    'statusHistory': [
      {'status': 'pending', 'time': '2026-08-10 14:00'},
      {'status': 'reviewed', 'time': '2026-08-11 10:00'},
      {'status': 'in_production', 'time': '2026-08-12 09:00'},
      {'status': 'ready', 'time': '2026-08-16 16:00'},
      {'status': 'delivered', 'time': '2026-08-18 13:00'},
    ],
    'notes': '',
  },
  {
    'id': 'ORD-1003',
    'status': 'pending',
    'product': 'Acrylic Sign Board',
    'material': 'Acrylic',
    'lighting': 'Backlit',
    'length': 6,
    'width': 2,
    'quantity': 1,
    'installation': true,
    'transportation': true,
    'address': 'Office 3, DHA Phase 5, Lahore',
    'estimatedPrice': 9800,
    'gst': 1503,
    'createdAt': '2026-09-28',
    'updatedAt': '2026-09-28',
    'statusHistory': [
      {'status': 'pending', 'time': '2026-09-28 16:45'},
    ],
    'notes': '',
  },
];

final _mockServices = <Map<String, dynamic>>[
  {
    'id': 'SRV-2001',
    'status': 'work_in_progress',
    'category': 'LED Problem',
    'description':
        'LED panel flickering badly at night, some modules are dead.',
    'address': 'Shop 12, Main Market, Lahore',
    'priority': 'high',
    'technicianName': 'M. Kashif',
    'createdAt': '2026-09-25',
    'statusHistory': [
      {'status': 'pending', 'time': '2026-09-25 09:00'},
      {'status': 'assigned', 'time': '2026-09-25 11:30'},
      {'status': 'accepted', 'time': '2026-09-25 14:00'},
      {'status': 'work_in_progress', 'time': '2026-09-26 10:00'},
    ],
  },
  {
    'id': 'SRV-2002',
    'status': 'completed',
    'category': 'Physical Damage',
    'description': 'Sign board broken after storm, needs full replacement.',
    'address': 'Plot 5, Gulberg III, Lahore',
    'priority': 'normal',
    'technicianName': 'S. Hassan',
    'createdAt': '2026-08-20',
    'statusHistory': [
      {'status': 'pending', 'time': '2026-08-20 08:00'},
      {'status': 'assigned', 'time': '2026-08-20 10:00'},
      {'status': 'completed', 'time': '2026-08-22 17:00'},
    ],
  },
  {
    'id': 'SRV-2003',
    'status': 'assigned',
    'category': 'Electrical Issue',
    'description': 'Sign board not turning on, suspect wiring issue.',
    'address': 'Office 3, DHA Phase 5, Lahore',
    'priority': 'normal',
    'technicianName': 'A. Rehman',
    'createdAt': '2026-09-29',
    'statusHistory': [
      {'status': 'pending', 'time': '2026-09-29 12:00'},
      {'status': 'assigned', 'time': '2026-09-29 15:00'},
    ],
  },
];

final _mockNotifications = <Map<String, dynamic>>[
  {
    'id': 'N001',
    'title': 'Order In Production',
    'body': 'Your order ORD-1001 has moved to production.',
    'type': 'order',
    'read': false,
    'createdAt': '2026-09-22 11:00',
  },
  {
    'id': 'N002',
    'title': 'Technician Assigned',
    'body': 'M. Kashif has been assigned to your service request SRV-2001.',
    'type': 'service',
    'read': false,
    'createdAt': '2026-09-25 11:30',
  },
  {
    'id': 'N003',
    'title': 'Work In Progress',
    'body': 'Technician has started work on SRV-2001.',
    'type': 'service',
    'read': true,
    'createdAt': '2026-09-26 10:00',
  },
  {
    'id': 'N004',
    'title': 'Order Delivered',
    'body': 'Your order ORD-1002 has been delivered successfully.',
    'type': 'order',
    'read': true,
    'createdAt': '2026-08-18 13:00',
  },
  {
    'id': 'N005',
    'title': 'New Order Received',
    'body': 'Your order ORD-1003 has been received and is under review.',
    'type': 'order',
    'read': false,
    'createdAt': '2026-09-28 16:45',
  },
];

final _mockWallet = <String, dynamic>{
  'balance': 0.0,
  'totalCashbackEarned': 0.0,
  'transactions': <Map<String, dynamic>>[],
};

Map<String, dynamic> _mockQuote(Map<String, dynamic> body) {
  final l = (body['length'] as num?)?.toDouble() ?? 10;
  final w = (body['width'] as num?)?.toDouble() ?? 3;
  final q = (body['quantity'] as num?)?.toInt() ?? 1;
  final area = l * w * q;
  final productCost = (area * 180).roundToDouble();
  final materialCost = (area * 60).roundToDouble();
  final lightingCost =
      body['lighting'] == 'No Lighting' ? 0.0 : (area * 45).roundToDouble();
  final installation = body['installation'] == true ? 1500.0 : 0.0;
  final transportation = body['transportation'] == true ? 800.0 : 0.0;
  final sub =
      productCost + materialCost + lightingCost + installation + transportation;
  final gst = (sub * 0.18).roundToDouble();
  return {
    'productCost': productCost,
    'materialCost': materialCost,
    'lightingCost': lightingCost,
    'installation': installation,
    'transportation': transportation,
    'gst': gst,
    'estimatedPrice': sub + gst,
  };
}

const _mockAiReplies = [
  'Great choice! LED sign boards are energy-efficient and bright even in direct sunlight.',
  'For outdoor signage, ACP (Aluminium Composite Panel) with LED lighting is our most popular combination.',
  'Typical turnaround for a standard LED sign board is 5ΓÇô7 working days after order confirmation.',
  'Our pricing is based on area (length ├ù width), material, lighting type, and add-ons like installation.',
  'You can track your order status anytime from the Track tab at the bottom of the screen.',
  'For emergency repairs, use the Service tab and select "Emergency" as the category ΓÇö we prioritise those.',
  'We offer a 6-month warranty on all LED modules. Contact us via service request for warranty claims.',
  'Our most popular sign board size is 10 ft ├ù 3 ft for shop fronts. Would you like a quote for that?',
];
int _aiIndex = 0;

// ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

class ApiClient {
  ApiClient({String? baseUrl, this.mockMode = false, http.Client? httpClient})
      : baseUrl = (baseUrl ??
                const String.fromEnvironment(
                  'API_URL',
                  defaultValue: 'https://signfix.me/api',
                ))
            .replaceAll(RegExp(r'/$'), ''),
        _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final bool mockMode;
  final http.Client _httpClient;
  String? _token;
  String? _userEmail;
  String? get token => _token;

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _userEmail = prefs.getString('userEmail');
    // Γ£à Restore persisted profile data
    final savedName = prefs.getString('customer_name');
    final savedPhoto = prefs.getString('customer_photo');
    if (savedName != null && savedName.isNotEmpty) {
      _mockProfile['name'] = savedName;
    }
    if (_userEmail != null && _userEmail!.isNotEmpty) {
      _mockProfile['email'] = _userEmail!;
    }
    if (savedPhoto != null && savedPhoto.isNotEmpty) {
      _mockProfile['profilePhotoPath'] = savedPhoto;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      _token = 'mock-customer-token';
      _userEmail = email.trim();
      _mockProfile['email'] = _userEmail!;
      // Restore saved name if exists
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('customer_name');
      if (savedName != null && savedName.isNotEmpty) {
        _mockProfile['name'] = savedName;
      }
      await prefs.setString('token', _token!);
      await prefs.setString('userEmail', _userEmail!);
      return {
        'token': _token,
        'user': {
          'email': _userEmail,
          'name': _mockProfile['name'],
          'role': 'customer'
        }
      };
    }
    final data = await _request('POST', '/auth/login', body: {
      'email': email.trim(),
      'password': password,
      'portal': 'customer',
    });
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const ApiException('Login token was not returned.');
    }
    _token = token;
    _userEmail = email.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('userEmail', _userEmail!);
    return data;
  }

  Future<Map<String, dynamic>> register(
      String name, String email, String phone, String password) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      _token = 'mock-customer-token';
      _userEmail = email.trim();
      _mockProfile['name'] = name;
      _mockProfile['email'] = email.trim();
      _mockProfile['phone'] = phone;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      await prefs.setString('userEmail', _userEmail!);
      await prefs.setString('customer_name', name); // Γ£à save name
      return {
        'token': _token,
        'user': {'email': _userEmail, 'name': name, 'role': 'customer'}
      };
    }
    final data = await _request('POST', '/auth/register', body: {
      'name': name,
      'email': email.trim(),
      'mobile': phone,
      'password': password
    });
    final token = data['token']?.toString();
    if (token != null && token.isNotEmpty) {
      _token = token;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
    }
    return data;
  }

  Future<void> logout() async {
    try {
      if (_token != null) await _request('POST', '/auth/logout');
    } catch (_) {}
    _token = null;
    _userEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userEmail');
  }

  // ── Password Reset ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> forgotPassword(String identifier) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      return {
        'message':
            'If the account exists, a password reset OTP has been sent to the registered email address.'
      };
    }
    return _request('POST', '/auth/forgot-password',
        body: {'identifier': identifier.trim()});
  }

  Future<Map<String, dynamic>> verifyResetOtp(
      String identifier, String otp) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      if (otp == '123456') {
        return {
          'verified': true,
          'resetToken':
              'mock-reset-token-${DateTime.now().millisecondsSinceEpoch}'
        };
      }
      throw const ApiException('Invalid or expired OTP');
    }
    return _request('POST', '/auth/verify-otp', body: {
      'identifier': identifier.trim(),
      'otp': otp.trim(),
      'purpose': 'reset_password',
    });
  }

  Future<Map<String, dynamic>> resetPassword(
      String resetToken, String password) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      return {'message': 'Password reset successfully.'};
    }
    return _request('POST', '/auth/reset-password', body: {
      'resetToken': resetToken,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> getProfile() async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      return {
        ..._mockProfile,
        'walletBalance': (_mockWallet['balance'] as num?)?.toDouble() ?? 0.0,
        'totalCashbackEarned':
            (_mockWallet['totalCashbackEarned'] as num?)?.toDouble() ?? 0.0,
      };
    }
    return _request('GET', '/customer/profile');
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      _mockProfile.addAll(body);
      // Γ£à persist name so it survives app restart
      final prefs = await SharedPreferences.getInstance();
      if (body.containsKey('name')) {
        await prefs.setString('customer_name', body['name'].toString());
      }
      if (body.containsKey('profilePhotoPath')) {
        await prefs.setString(
            'customer_photo', body['profilePhotoPath']?.toString() ?? '');
      }
      return Map<String, dynamic>.from(_mockProfile);
    }
    return _request('PATCH', '/customer/profile', body: body);
  }

  Future<List<dynamic>> products() async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      return [
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
      ].map((x) => {'name': x}).toList();
    }
    return (await _request('GET', '/products'))['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> orderOptions() async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      return {
        'signBoardTypes': [
          {'id': 1, 'name': 'LED Sign Board', 'basePrice': 150},
          {'id': 2, 'name': 'Acrylic Sign Board', 'basePrice': 150},
        ],
        'materials': [
          {'id': 1, 'name': 'Acrylic', 'price': 50, 'pricingMethod': 'sqft'},
          {'id': 2, 'name': 'ACP', 'price': 60, 'pricingMethod': 'sqft'},
        ],
        'lighting': [
          {'id': 1, 'name': 'LED', 'price': 30, 'pricingMethod': 'sqft'},
          {'id': 2, 'name': 'No Lighting', 'price': 0, 'pricingMethod': 'sqft'},
        ],
        'units': ['ft', 'in', 'cm', 'm'],
        'additionalOptions': [
          'installation',
          'transportation',
          'design',
          'electricalWork',
          'mountingStructure',
          'accessories',
          'customization',
        ],
        'priceLabel': 'Estimated Price',
        'priceNotice':
            'Final quotation may change after Admin review/measurement.',
      };
    }
    final response = await _request('GET', '/customer/order-options');
    final data = response['data'];
    return Map<String, dynamic>.from(data is Map ? data : response);
  }

  Future<Map<String, dynamic>> calculate(Map<String, dynamic> body) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      return _mockQuote(body);
    }
    return _request('POST', '/calculator', body: body);
  }

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> body) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      final id = 'ORD-${1000 + _mockOrders.length + 1}';
      final double estimatedPrice =
          (body['estimatedPrice'] as num?)?.toDouble() ?? 0.0;
      double currentBal = (_mockWallet['balance'] as num?)?.toDouble() ?? 0.0;
      double totalEarned =
          (_mockWallet['totalCashbackEarned'] as num?)?.toDouble() ?? 0.0;
      final bool useWallet = body['useWallet'] == true;
      final double walletApplied =
          useWallet ? min(currentBal, estimatedPrice) : 0.0;
      final double finalPrice = max(0.0, estimatedPrice - walletApplied);
      final txList = _mockWallet['transactions'] as List<Map<String, dynamic>>;

      if (walletApplied > 0) {
        final double prev = currentBal;
        currentBal -= walletApplied;
        txList.insert(0, {
          'transactionId': txList.length + 1,
          'orderNo': id,
          'type': 'wallet_debit',
          'amount': walletApplied,
          'previousBalance': prev,
          'balanceAfter': currentBal,
          'status': 'successful',
          'description': 'Wallet balance applied to Order $id',
          'createdAt': DateTime.now().toIso8601String(),
        });
      }

      final String? bannerId = body['promotionBannerId']?.toString();
      final bool eligible = bannerId != null &&
          const {'home_banner_1', 'home_banner_2', 'home_banner_3'}
              .contains(bannerId);
      final double cashback = eligible ? 200.0 : 0.0;
      if (cashback > 0) {
        final double prev = currentBal;
        currentBal += cashback;
        totalEarned += cashback;
        txList.insert(0, {
          'transactionId': txList.length + 1,
          'orderNo': id,
          'type': 'cashback_credit',
          'amount': cashback,
          'previousBalance': prev,
          'balanceAfter': currentBal,
          'status': 'successful',
          'description':
              'Cashback ₹200 credited for promotional banner order $bannerId - Order $id',
          'createdAt': DateTime.now().toIso8601String(),
        });
      }

      _mockWallet['balance'] = currentBal;
      _mockWallet['totalCashbackEarned'] = totalEarned;

      _mockOrders.insert(0, {
        ...body,
        'id': id,
        'estimatedPrice': finalPrice,
        'walletDiscountApplied': walletApplied,
        'cashbackEarned': cashback,
        'status': 'under_review',
        'createdAt': DateTime.now().toString().substring(0, 10),
        'updatedAt': DateTime.now().toString().substring(0, 10),
        'statusHistory': [
          {
            'status': 'under_review',
            'time': DateTime.now().toString().substring(0, 16)
          }
        ],
      });
      _mockProfile['totalOrders'] = (_mockProfile['totalOrders'] as int) + 1;
      return {
        'id': id,
        'estimatedPrice': finalPrice,
        'walletDiscountApplied': walletApplied,
        'cashbackEarned': cashback,
        'message': 'Order placed successfully.',
      };
    }
    return _request('POST', '/orders', body: body);
  }

  Future<List<dynamic>> orders() async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      return List<dynamic>.from(_mockOrders);
    }
    return (await _request('GET', '/customer/orders'))['data']
            as List<dynamic>? ??
        [];
  }

  Future<Map<String, dynamic>> wallet() async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      return {
        ..._mockWallet,
        'transactions': List<Map<String, dynamic>>.from(
          _mockWallet['transactions'] as List<Map<String, dynamic>>,
        ),
      };
    }
    return _request('GET', '/customer/wallet');
  }

  Future<Map<String, dynamic>> orderDetail(String id) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      final order = _mockOrders.firstWhere(
        (o) => o['id'] == id,
        orElse: () => {},
      );
      if (order.isEmpty) throw ApiException('Order $id not found.');
      return Map<String, dynamic>.from(order);
    }
    return _request('GET', '/customer/orders/$id');
  }

  Future<Map<String, dynamic>> createService(Map<String, dynamic> body) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      final id = 'SRV-${2000 + _mockServices.length + 1}';
      _mockServices.insert(0, {
        ...body,
        'id': id,
        'status': 'pending',
        'priority': 'normal',
        'technicianName': null,
        'createdAt': DateTime.now().toString().substring(0, 10),
        'statusHistory': [
          {
            'status': 'pending',
            'time': DateTime.now().toString().substring(0, 16)
          }
        ],
      });
      _mockProfile['totalServices'] =
          (_mockProfile['totalServices'] as int) + 1;
      return {'id': id, 'message': 'Service request submitted successfully.'};
    }
    return _request('POST', '/services', body: body);
  }

  Future<List<dynamic>> services() async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      return List<dynamic>.from(_mockServices);
    }
    return (await _request('GET', '/customer/services'))['data']
            as List<dynamic>? ??
        [];
  }

  Future<List<dynamic>> notifications() async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      return List<dynamic>.from(_mockNotifications);
    }
    return (await _request('GET', '/customer/notifications'))['data']
            as List<dynamic>? ??
        [];
  }

  Future<void> markNotificationRead(String id) async {
    if (mockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      final n =
          _mockNotifications.firstWhere((n) => n['id'] == id, orElse: () => {});
      if (n.isNotEmpty) n['read'] = true;
      return;
    }
    await _request('PATCH', '/customer/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    if (mockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      for (final n in _mockNotifications) {
        n['read'] = true;
      }
      return;
    }
    await _request('PATCH', '/customer/notifications/read-all');
  }

  Future<void> registerDeviceToken(String token) async {
    if (mockMode) return;
    try {
      await _request('POST', '/customer/notifications/devices',
          body: {'token': token, 'platform': 'android'});
    } catch (_) {} // non-critical — ignore failures
  }

  Future<void> unregisterDeviceToken(String token) async {
    if (mockMode) return;
    try {
      await _request('DELETE', '/customer/notifications/devices',
          body: {'token': token});
    } catch (_) {}
  }

  Future<Map<String, dynamic>> chat(String message) async {
    if (mockMode) {
      await Future.delayed(const Duration(milliseconds: 900));
      final reply = _mockAiReplies[_aiIndex % _mockAiReplies.length];
      _aiIndex++;
      return {'reply': reply};
    }
    return _request('POST', '/customer/ai/chat', body: {'message': message});
  }

  Future<Map<String, dynamic>> upload(File file, String kind) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      return {
        'url':
            'https://mock-cdn.signfix.app/uploads/${kind}_${DateTime.now().millisecondsSinceEpoch}.jpg'
      };
    }
    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/uploads'));
    _applyAuth(request.headers);
    request.fields['kind'] = kind;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await http.Response.fromStream(await request.send());
    return _decode(response);
  }

  Future<Map<String, dynamic>> uploadDesign(
    File file, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final size = await file.length();
    final extension = file.path.toLowerCase().split('.').last;
    if (!const {'jpg', 'jpeg', 'png', 'webp', 'pdf'}.contains(extension)) {
      throw const ApiException('Choose a JPG, PNG, WEBP, or PDF file.');
    }
    if (size > 8 * 1024 * 1024) {
      throw const ApiException('The design file must be 8 MB or smaller.');
    }
    if (mockMode) {
      await Future.delayed(_mockDelay);
      onProgress?.call(size, size);
      return {
        'url':
            'https://mock-cdn.signfix.app/uploads/design_${DateTime.now().millisecondsSinceEpoch}.$extension',
      };
    }

    final multipart =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/uploads'));
    if (_token != null) multipart.headers['Authorization'] = 'Bearer $_token';
    multipart.files.add(await http.MultipartFile.fromPath('file', file.path));
    final multipartBody = multipart.finalize();
    final streamedRequest = http.StreamedRequest('POST', multipart.url)
      ..headers.addAll(multipart.headers)
      ..contentLength = multipart.contentLength;
    final responseFuture = _httpClient.send(streamedRequest);
    var sent = 0;
    final body = multipartBody.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, sink) {
          sent += chunk.length;
          onProgress?.call(sent, multipart.contentLength);
          sink.add(chunk);
        },
      ),
    );
    await streamedRequest.sink.addStream(body);
    await streamedRequest.sink.close();
    final response = await http.Response.fromStream(await responseFuture);
    return _decode(response);
  }

  // ΓöÇΓöÇ Customer Dashboard ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  Future<Map<String, dynamic>> getCustomerDashboard() =>
      _request('GET', '/customer/dashboard');

  // ΓöÇΓöÇ Order Actions ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  Future<Map<String, dynamic>> cancelOrder(String id) =>
      _request('POST', '/customer/orders/$id/cancel');

  // ΓöÇΓöÇ Service Actions ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  Future<Map<String, dynamic>> cancelService(String id) =>
      _request('POST', '/customer/services/$id/cancel');

  Future<Map<String, dynamic>> confirmServiceCompletion(
          String serviceId, String otp) =>
      _request('POST', '/customer/services/$serviceId/confirm-completion',
          body: {'otp': otp});

  Future<Map<String, dynamic>> reviewService(
          String serviceId, Map<String, dynamic> data) =>
      _request('POST', '/customer/services/$serviceId/review', body: data);

  Future<Map<String, dynamic>> reviewOrder(
          String orderId, Map<String, dynamic> data) =>
      _request('POST', '/customer/orders/$orderId/review', body: data);

  // ΓöÇΓöÇ Quotations ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  Future<List<dynamic>> getQuotations() async =>
      (await _request('GET', '/customer/quotations'))['data']
          as List<dynamic>? ??
      [];

  Future<Map<String, dynamic>> getQuotation(String id) =>
      _request('GET', '/customer/quotations/$id');

  Future<Uint8List> quotationPdf(String id) async {
    final request = http.Request(
      'GET',
      Uri.parse('$baseUrl/customer/quotations/$id/pdf'),
    );
    _applyAuth(request.headers);
    final response =
        await http.Response.fromStream(await _httpClient.send(request));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(response);
    }
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> quotationAction(String id,
          {required String action, String? notes}) =>
      _request('POST', '/customer/quotations/$id/action', body: {
        'action': action,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      });

  Future<Map<String, dynamic>> approveQuotation(String id, {String? notes}) =>
      quotationAction(id, action: 'approve', notes: notes);

  Future<Map<String, dynamic>> rejectQuotation(String id, {String? notes}) =>
      quotationAction(id, action: 'reject', notes: notes);

  Future<Map<String, dynamic>> requestQuotationChanges(
          String id, String message) =>
      quotationAction(id, action: 'request_changes', notes: message);

  // ΓöÇΓöÇ Payments ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  Future<Map<String, dynamic>> createPaymentIntent(
      Map<String, dynamic> data) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      final mockIntentId = 'pi_mock_${DateTime.now().millisecondsSinceEpoch}';
      return {
        'id': mockIntentId,
        'checkout': {
          'keyId': const String.fromEnvironment('RAZORPAY_KEY',
              defaultValue: 'rzp_live_TZRwgnPCEkDeu4'),
          'orderId': 'order_mock_${DateTime.now().millisecondsSinceEpoch}',
          'amount': ((data['amount'] as num?)?.toDouble() ?? 0) * 100, // paise
          'currency': 'INR',
          'name': 'SignFix',
          'description': 'Order payment',
        },
      };
    }
    return _request('POST', '/customer/payments/intents', body: data);
  }

  Future<Map<String, dynamic>> createOrderPaymentIntent(
      Map<String, dynamic> data) async {
    if (mockMode) return createPaymentIntent(data);

    final requestData = Map<String, dynamic>.from(data)..remove('amount');
    return _request(
      'POST',
      '/customer/payments/order-intents',
      body: requestData,
    );
  }

  Future<Map<String, dynamic>> verifyPayment(
          String paymentId, Map<String, dynamic> data) =>
      _request('POST', '/customer/payments/$paymentId/verify', body: data);

  Future<Map<String, dynamic>> reportPaymentFailure(
          String paymentId, Map<String, dynamic> data) =>
      _request('POST', '/customer/payments/$paymentId/failure', body: data);

  Future<List<dynamic>> getPayments() async =>
      (await _request('GET', '/customer/payments'))['data'] as List<dynamic>? ??
      [];

  // ── AI & Designs ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createDesignRequest(Map<String, dynamic> data) =>
      _request('POST', '/customer/designs', body: data);

  Future<Map<String, dynamic>> generateDesignPreview(
          Map<String, dynamic> data) =>
      _request('POST', '/customer/designs/preview', body: data);

  Future<Map<String, dynamic>> generateDesignConcept(int designId,
          {String? prompt}) =>
      _request('POST', '/customer/designs/$designId/generate',
          body: {if (prompt != null) 'prompt': prompt});

  Future<Map<String, dynamic>> getDesign(int designId) =>
      _request('GET', '/customer/designs/$designId');

  Future<List<dynamic>> getDesigns() async =>
      (await _request('GET', '/customer/designs'))['data'] as List<dynamic>? ??
      [];

  Future<Map<String, dynamic>> getAiConfig() =>
      _request('GET', '/customer/ai/config');

  Future<List<dynamic>> getAiConversations() async =>
      (await _request('GET', '/customer/ai/conversations'))['data']
          as List<dynamic>? ??
      [];

  // ── Address & Location Autocomplete ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSavedAddresses() async {
    final res = await _request('GET', '/customer/addresses');
    if (res['data'] is List) {
      return (res['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> saveCustomerAddress(Map<String, dynamic> data) =>
      _request('POST', '/customer/addresses', body: data);

  Future<Map<String, dynamic>> updateCustomerAddress(
          dynamic id, Map<String, dynamic> data) =>
      _request('PATCH', '/customer/addresses/$id', body: data);

  Future<void> deleteCustomerAddress(dynamic id) =>
      _request('DELETE', '/customer/addresses/$id');

  Future<List<Map<String, dynamic>>> autocompleteLocation(String query,
      {String? sessionToken, String? countryCodes}) async {
    final queryParameters = <String, String>{'input': query.trim()};
    if (sessionToken != null) queryParameters['sessionToken'] = sessionToken;
    if (countryCodes != null) queryParameters['countryCodes'] = countryCodes;
    final path =
        '/customer/location/autocomplete?${Uri(queryParameters: queryParameters).query}';
    final res = await _request('GET', path);
    final data = res['data'];
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getLocationDetails(String placeId,
      {String? sessionToken,
      String? provider,
      double? lat,
      double? lon}) async {
    var path =
        '/customer/location/details?placeId=${Uri.encodeComponent(placeId)}';
    if (sessionToken != null) {
      path += '&sessionToken=${Uri.encodeComponent(sessionToken)}';
    }
    if (provider != null) {
      path += '&provider=${Uri.encodeComponent(provider)}';
    }
    if (lat != null && lon != null) path += '&latitude=$lat&longitude=$lon';
    final res = await _request('GET', path);
    return res['data'] is Map
        ? Map<String, dynamic>.from(res['data'] as Map)
        : res;
  }

  Future<Map<String, dynamic>> reverseLocation(
      double latitude, double longitude) async {
    final path = Uri(
      path: '/customer/location/reverse',
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      },
    ).toString();
    final res = await _request('GET', path);
    return res['data'] is Map
        ? Map<String, dynamic>.from(res['data'] as Map)
        : res;
  }

  // ΓöÇΓöÇ Account ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  Future<void> changePassword(String oldPassword, String newPassword) async {
    await _request('POST', '/auth/change-password',
        body: {'oldPassword': oldPassword, 'newPassword': newPassword});
  }

  Future<void> deleteAccount() async {
    await _request('DELETE', '/customer/account');
    await logout();
  }

  void _applyAuth(Map<String, String> headers) {
    if (_token != null) headers['Authorization'] = 'Bearer $_token';
  }

  Future<Map<String, dynamic>> _request(String method, String path,
      {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_token != null) headers['Authorization'] = 'Bearer $_token';
    const timeout = Duration(seconds: 30);
    try {
      late http.Response response;
      switch (method) {
        case 'GET':
          response =
              await _httpClient.get(uri, headers: headers).timeout(timeout);
          break;
        case 'POST':
          response = await _httpClient
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(timeout);
          break;
        case 'PATCH':
          response = await _httpClient
              .patch(uri, headers: headers, body: jsonEncode(body))
              .timeout(timeout);
          break;
        case 'DELETE':
          response = await _httpClient
              .delete(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(timeout);
          break;
        default:
          throw ApiException('Unsupported HTTP method: $method');
      }
      return _decode(response);
    } on TimeoutException {
      throw const ApiException(
          'Request timed out. Please check your connection and try again.');
    } on SocketException {
      throw const ApiException(
          'Cannot connect to SignFix. Check your network or API URL.');
    } on HttpException {
      throw const ApiException('The SignFix server could not be reached.');
    } on http.ClientException {
      throw const ApiException(
          'Server connection was closed unexpectedly. Please check your network or try again.');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          decoded is Map ? (decoded['error'] ?? decoded['message']) : null;
      final field = decoded is Map ? decoded['field']?.toString() : null;
      final code = decoded is Map ? decoded['code']?.toString() : null;
      String errorMsg =
          message?.toString() ?? 'Request failed (${response.statusCode}).';
      // Auto-clear token on 401 so next request forces re-login
      if (response.statusCode == 401) {
        _token = null;
        _userEmail = null;
        SharedPreferences.getInstance().then((prefs) {
          prefs.remove('token');
          prefs.remove('userEmail');
        });
      }
      // Show validation field errors if present
      if (decoded is Map && decoded['details'] != null) {
        final details = decoded['details'];
        if (details is Map && details.isNotEmpty) {
          final fields = details.entries
              .map((e) => '${e.key}: ${(e.value as List).join(', ')}')
              .join(' | ');
          errorMsg = '$errorMsg — $fields';
        }
      }
      throw ApiException(
        errorMsg,
        statusCode: response.statusCode,
        field: field,
        code: code,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
          'Invalid response (HTTP ${response.statusCode}): ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}',
          statusCode: response.statusCode);
    }
    return decoded;
  }
}
