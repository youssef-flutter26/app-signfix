import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

// ─────────────────────────────────────────────
//  MOCK DATA — demo mode (no backend needed)
// ─────────────────────────────────────────────
const _mockDelay = Duration(milliseconds: 700);

final _mockProfile = <String, dynamic>{
  'id': 'TECH-001',
  'technicianId': 'TEC-0001',
  'name': 'Demo Technician',
  'email': 'technician@signfix.in',
  'phone': '03009876543',
  'skills': ['LED Wiring', 'ACP Fabrication', 'Site Installation'],
  'locationSharing': true,
  'profilePhotoPath': null,
  'emergencyContact': '03001112233',
  'totalJobsCompleted': 48,
  'rating': 4.7,
};

final _mockJobs = <Map<String, dynamic>>[
  {
    'id': 'JOB-3001',
    'customer': 'Ali Raza',
    'phone': '03001234567',
    'category': 'LED Sign Board Installation',
    'address': 'Shop 12, Main Market, Lahore',
    'latitude': 31.5204,
    'longitude': 74.3587,
    'status': 'assigned',
    'priority': 'normal',
    'scheduledAt': DateTime.now().toIso8601String().substring(0, 10),
    'description': 'Install a new 10×3 ft LED sign board at the shop front.',
    'evidencePhotos': <dynamic>[],
    'materials': <dynamic>[],
    'statusHistory': [
      {'status': 'assigned', 'time': '2026-09-30 08:00'},
    ],
  },
  {
    'id': 'JOB-3002',
    'customer': 'Fatima Khan',
    'phone': '03119876543',
    'category': 'Flex Sign Repair',
    'address': 'Plot 5, Gulberg III, Lahore',
    'latitude': 31.5107,
    'longitude': 74.3436,
    'status': 'work_in_progress',
    'priority': 'high',
    'scheduledAt': DateTime.now().toIso8601String().substring(0, 10),
    'description': 'Flex sign board has torn edges and backlight failure.',
    'evidencePhotos': <dynamic>[],
    'materials': <dynamic>[
      {'name': 'Flex Sheet 4×2 ft', 'quantity': 1, 'unit': 'pcs'},
    ],
    'statusHistory': [
      {'status': 'assigned', 'time': '2026-09-30 07:00'},
      {'status': 'accepted', 'time': '2026-09-30 07:30'},
      {'status': 'on_the_way', 'time': '2026-09-30 08:30'},
      {'status': 'reached_location', 'time': '2026-09-30 09:00'},
      {'status': 'work_in_progress', 'time': '2026-09-30 09:15'},
    ],
  },
  {
    'id': 'JOB-3003',
    'customer': 'Hassan Tariq',
    'phone': '03334455667',
    'category': 'Acrylic Board Replacement',
    'address': 'Office 7, DHA Phase 6, Lahore',
    'latitude': 31.4697,
    'longitude': 74.4023,
    'status': 'completed',
    'priority': 'normal',
    'scheduledAt': DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10),
    'description': 'Replace cracked acrylic board with new 8×2 ft panel.',
    'evidencePhotos': <dynamic>[],
    'materials': <dynamic>[
      {'name': 'Acrylic Sheet 8×2 ft', 'quantity': 1, 'unit': 'pcs'},
      {'name': 'LED Modules', 'quantity': 20, 'unit': 'pcs'},
    ],
    'statusHistory': [
      {'status': 'assigned', 'time': '2026-09-29 08:00'},
      {'status': 'completed', 'time': '2026-09-29 15:00'},
    ],
  },
  {
    'id': 'JOB-3004',
    'customer': 'Zara Ahmed',
    'phone': '03215556677',
    'category': 'Neon Sign Emergency Repair',
    'address': 'F-7 Markaz, Islamabad',
    'latitude': 33.7291,
    'longitude': 73.0436,
    'status': 'assigned',
    'priority': 'emergency',
    'scheduledAt': DateTime.now().toIso8601String().substring(0, 10),
    'description':
        'Neon sign completely dead after power surge. Urgent fix needed.',
    'evidencePhotos': <dynamic>[],
    'materials': <dynamic>[],
    'statusHistory': [
      {'status': 'assigned', 'time': '2026-09-30 10:00'},
    ],
  },
  {
    'id': 'JOB-3005',
    'customer': 'Bilal Hussain',
    'phone': '03456789012',
    'category': 'Outdoor Signage Installation',
    'address': 'Tariq Road, Karachi',
    'latitude': 24.8607,
    'longitude': 67.0011,
    'status': 'accepted',
    'priority': 'normal',
    'scheduledAt': DateTime.now().toIso8601String().substring(0, 10),
    'description': 'Install 12×4 ft outdoor ACP sign board with LED lighting.',
    'evidencePhotos': <dynamic>[],
    'materials': <dynamic>[],
    'statusHistory': [
      {'status': 'assigned', 'time': '2026-09-30 06:00'},
      {'status': 'accepted', 'time': '2026-09-30 06:45'},
    ],
  },
];

final _mockNotifications = <Map<String, dynamic>>[
  {
    'id': 'TN001',
    'title': 'New Emergency Job',
    'body': 'JOB-3004 assigned — Neon Sign Emergency in Islamabad.',
    'type': 'emergency',
    'read': false,
    'createdAt': '2026-09-30 10:00',
  },
  {
    'id': 'TN002',
    'title': 'New Job Assigned',
    'body': 'JOB-3001 assigned — LED Sign Board Installation in Lahore.',
    'type': 'job',
    'read': false,
    'createdAt': '2026-09-30 08:00',
  },
  {
    'id': 'TN003',
    'title': 'Job Reassigned',
    'body': 'JOB-3005 has been reassigned to you.',
    'type': 'job',
    'read': true,
    'createdAt': '2026-09-29 17:00',
  },
  {
    'id': 'TN004',
    'title': 'Job Completed',
    'body': 'Great work! JOB-3003 marked as completed.',
    'type': 'completed',
    'read': true,
    'createdAt': '2026-09-29 15:00',
  },
];

// ─────────────────────────────────────────────

class TechnicianApi {
  TechnicianApi({String? baseUrl, this.mockMode = false})
      : baseUrl = (baseUrl ??
                const String.fromEnvironment(
                  'API_URL',
                  defaultValue: 'https://signfix.me/api',
                ))
            .replaceAll(RegExp(r'/$'), '');

  final String baseUrl;
  final bool mockMode;
  String? _token;
  String? get token => _token;

  Future<void> restoreSession() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString('technician_token');
    // ✅ Restore persisted name and photo
    final savedName = p.getString('tech_name');
    final savedPhoto = p.getString('tech_photo');
    if (savedName != null && savedName.isNotEmpty) {
      _mockProfile['name'] = savedName;
    }
    if (savedPhoto != null && savedPhoto.isNotEmpty) {
      _mockProfile['profilePhotoPath'] = savedPhoto;
    }
  }

  Future<void> login(String email, String password) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      _token = 'mock-technician-token';
      _mockProfile['email'] = email.trim();
      // Restore saved name if exists
      final p = await SharedPreferences.getInstance();
      final savedName = p.getString('tech_name');
      if (savedName != null && savedName.isNotEmpty) {
        _mockProfile['name'] = savedName;
      }
      await p.setString('technician_token', _token!);
      return;
    }
    final d = await _request('POST', '/auth/login', body: {
      'email': email.trim(),
      'password': password,
      'portal': 'technician',
    });
    final token = d['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const ApiException('Login token was not returned.');
    }
    _token = token;
    final p = await SharedPreferences.getInstance();
    await p.setString('technician_token', token);
  }

  Future<void> loginWithGoogle({
    String? idToken,
    String? email,
    String? name,
  }) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      _token = 'mock-technician-google-token';
      _mockProfile['email'] = email?.trim() ?? 'tech@signfix.in';
      final p = await SharedPreferences.getInstance();
      await p.setString('technician_token', _token!);
      return;
    }
    final d = await _request('POST', '/auth/google', body: {
      'idToken': idToken ?? 'google-auth-client-token',
      if (email != null) 'email': email.trim(),
      if (name != null) 'name': name.trim(),
      'portal': 'technician',
      'role': 'technician',
    });
    final token = d['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const ApiException('Login token was not returned.');
    }
    _token = token;
    final p = await SharedPreferences.getInstance();
    await p.setString('technician_token', token);
  }

  Future<void> loginWithFirebasePhone({
    required String idToken,
    String? name,
  }) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      _token = 'mock-technician-phone-token';
      final p = await SharedPreferences.getInstance();
      await p.setString('technician_token', _token!);
      return;
    }

    final data = await _request('POST', '/auth/firebase-phone', body: {
      'idToken': idToken,
      'role': 'technician',
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    });
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const ApiException('Login token was not returned.');
    }
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('technician_token', token);
    final email = data['user']?['email']?.toString();
    if (email != null && email.isNotEmpty) {
      await prefs.setString('technician_email', email);
    }
  }

  Future<void> logout() async {
    _token = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('technician_token');
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

  Future<Map<String, dynamic>> dashboard() async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final todayJobs = _mockJobs
          .where((j) => j['scheduledAt']?.toString().startsWith(today) == true)
          .length;
      final assigned = _mockJobs.where((j) => j['status'] == 'assigned').length;
      final pending = _mockJobs
          .where((j) => ['assigned', 'accepted'].contains(j['status']))
          .length;
      final inProgress =
          _mockJobs.where((j) => j['status'] == 'work_in_progress').length;
      final completed =
          _mockJobs.where((j) => j['status'] == 'completed').length;
      final emergency =
          _mockJobs.where((j) => j['priority'] == 'emergency').length;
      return {
        'today': todayJobs,
        'assigned': assigned,
        'pending': pending,
        'inProgress': inProgress,
        'completed': completed,
        'emergency': emergency,
        'totalCompleted': _mockProfile['totalJobsCompleted'],
        'rating': _mockProfile['rating'],
      };
    }
    final res = await _request('GET', '/technician/dashboard');
    return (res['data'] as Map<String, dynamic>?) ?? res;
  }

  Future<Map<String, dynamic>> getProfile() async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      return Map<String, dynamic>.from(_mockProfile);
    }
    final res = await _request('GET', '/technician/profile');
    return (res['data'] as Map<String, dynamic>?) ?? res;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      _mockProfile.addAll(body);
      // ✅ Persist name and photo
      final p = await SharedPreferences.getInstance();
      if (body.containsKey('name') && (body['name'] as String).isNotEmpty) {
        await p.setString('tech_name', body['name'].toString());
      }
      if (body.containsKey('profilePhotoPath')) {
        await p.setString(
            'tech_photo', body['profilePhotoPath']?.toString() ?? '');
      }
      return Map<String, dynamic>.from(_mockProfile);
    }
    final res = await _request('PATCH', '/technician/profile', body: body);
    return (res['data'] as Map<String, dynamic>?) ?? res;
  }

  Future<List<dynamic>> jobs() async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      return List<dynamic>.from(_mockJobs);
    }
    final res = await _request('GET', '/technician/jobs');
    final data = res['data'];
    if (data is List) return data;
    if (data is Map) return (data['items'] as List<dynamic>?) ?? [];
    return [];
  }

  Future<Map<String, dynamic>> updateJob(String id, String status,
      {Map<String, dynamic>? extra}) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      final job = _mockJobs.firstWhere((j) => j['id'] == id, orElse: () => {});
      if (job.isNotEmpty) {
        job['status'] = status;
        (job['statusHistory'] as List).add({
          'status': status,
          'time': DateTime.now().toString().substring(0, 16),
        });
        if (extra != null) job.addAll(extra);
      }
      return {
        'id': id,
        'status': status,
        'message': 'Job updated successfully.'
      };
    }
    return _request(
        'PATCH', '/technician/jobs/${Uri.encodeComponent(id)}/status',
        body: {'status': status, ...?extra});
  }

  Future<List<dynamic>> notifications() async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      return List<dynamic>.from(_mockNotifications);
    }
    return (await _request('GET', '/technician/notifications'))['data']
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
    await _request('PATCH', '/technician/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    if (mockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      for (final n in _mockNotifications) {
        n['read'] = true;
      }
      return;
    }
    await _request('PATCH', '/technician/notifications/read-all');
  }

  Future<void> registerDeviceToken(String token) async {
    if (mockMode) return;
    try {
      await _request('POST', '/notifications/register',
          body: {'token': token, 'platform': 'android'});
    } catch (_) {} // non-critical — ignore failures
  }

  Future<void> unregisterDeviceToken(String token) async {
    if (mockMode) return;
    try {
      await _request('POST', '/technician/notifications/devices/unregister',
          body: {'token': token});
    } catch (_) {}
  }

  // ── Self-Registration APIs ───────────────────────────────────────────────

  /// Step 1: Send OTP to the technician's email address
  Future<Map<String, dynamic>> sendOtp(String email, String mobile) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      // Mock: always succeeds, OTP is "123456" in demo mode
      return {'message': 'OTP sent to $email', 'expiresIn': 120};
    }
    return _request('POST', '/auth/technician/register/send-otp',
        body: {'email': email, 'mobile': mobile});
  }

  /// Step 2: Verify OTP — returns verification token
  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      if (otp == '123456') {
        return {
          'verified': true,
          'verificationToken':
              'mock-otp-token-${DateTime.now().millisecondsSinceEpoch}'
        };
      }
      throw const ApiException('Invalid OTP. Please try again.');
    }
    return _request('POST', '/auth/technician/register/verify-otp',
        body: {'email': email, 'otp': otp});
  }

  /// Step 3: Submit registration — creates PENDING_APPROVAL account
  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      // Check duplicate mobile in mock
      if (data['mobile'] == '9999999999') {
        throw const ApiException(
            'This mobile number is already registered. Please log in or contact Admin.');
      }
      return {
        'id': 'REG-${DateTime.now().millisecondsSinceEpoch}',
        'status': 'PENDING_APPROVAL',
        'message':
            'Your registration has been received and is pending admin approval.',
        'submittedAt': DateTime.now().toIso8601String(),
      };
    }
    return _request('POST', '/auth/technician/register', body: data);
  }

  /// Check registration status (for pending approval screen)
  Future<Map<String, dynamic>> registrationStatus() async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      return {
        'status': 'PENDING_APPROVAL',
        'submittedAt':
            DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'message':
            'Your registration is under review. You will be notified once approved.',
      };
    }
    return _request('GET', '/auth/me');
  }

  // ── Job Detail & Actions ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getJobDetail(String jobId) =>
      _request('GET', '/technician/jobs/${Uri.encodeComponent(jobId)}');

  Future<Map<String, dynamic>> sendCompletionOtp(String jobId) => _request(
      'POST', '/technician/jobs/${Uri.encodeComponent(jobId)}/completion-otp');

  Future<Map<String, dynamic>> confirmJobCompletion(String jobId, String otp) =>
      _request('POST', '/technician/jobs/${Uri.encodeComponent(jobId)}/confirm',
          body: {'otp': otp});

  Future<Map<String, dynamic>> updateLocation(
          String jobId, double lat, double lng) =>
      _request(
          'POST', '/technician/jobs/${Uri.encodeComponent(jobId)}/location',
          body: {'latitude': lat, 'longitude': lng});

  Future<Map<String, dynamic>> uploadEvidence(
      String jobId, List<File> photos, String notes) async {
    final request = http.MultipartRequest(
        'POST',
        Uri.parse(
            '$baseUrl/technician/jobs/${Uri.encodeComponent(jobId)}/evidence'));
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    request.fields['notes'] = notes;
    for (final photo in photos) {
      request.files
          .add(await http.MultipartFile.fromPath('photos', photo.path));
    }
    return _decode(await http.Response.fromStream(await request.send()));
  }

  Future<Map<String, dynamic>> upload(
      File file, String kind, String jobId) async {
    if (mockMode) {
      await Future.delayed(_mockDelay);
      return {
        'url':
            'https://mock-cdn.signfix.app/uploads/${kind}_${jobId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      };
    }
    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/uploads'));
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    request.fields['kind'] = kind;
    request.fields['jobId'] = jobId;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    return _decode(await http.Response.fromStream(await request.send()));
  }

  Future<Map<String, dynamic>> _request(String method, String path,
      {Map<String, dynamic>? body}) async {
    final u = Uri.parse('$baseUrl$path');
    final h = <String, String>{
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
    const timeout = Duration(seconds: 30);
    try {
      late http.Response r;
      switch (method) {
        case 'GET':
          r = await http.get(u, headers: h).timeout(timeout);
          break;
        case 'POST':
          r = await http
              .post(u, headers: h, body: jsonEncode(body))
              .timeout(timeout);
          break;
        case 'PATCH':
          r = await http
              .patch(u, headers: h, body: jsonEncode(body))
              .timeout(timeout);
          break;
        default:
          throw ApiException('Unsupported HTTP method: $method');
      }
      return _decode(r);
    } on TimeoutException {
      throw const ApiException(
          'Request timed out. Please check your connection and try again.');
    } on SocketException {
      throw const ApiException(
          'Cannot connect to SignFix. Check your network or API URL.');
    }
  }

  Map<String, dynamic> _decode(http.Response r) {
    dynamic d;
    try {
      d = jsonDecode(r.body);
    } catch (_) {
      d = null;
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      final m = d is Map ? (d['error'] ?? d['message']) : null;
      final field = d is Map ? d['field']?.toString() : null;
      final code = d is Map ? d['code']?.toString() : null;
      String errorMsg = m?.toString() ?? 'Request failed (${r.statusCode}).';
      // Auto-clear token on 401
      if (r.statusCode == 401) {
        _token = null;
        SharedPreferences.getInstance().then((prefs) {
          prefs.remove('technician_token');
          prefs.remove('tech_name');
          prefs.remove('tech_photo');
        });
      }
      if (d is Map && d['details'] != null) {
        final details = d['details'];
        if (details is Map && details.isNotEmpty) {
          final fields = details.entries
              .map((e) => '${e.key}: ${(e.value as List).join(', ')}')
              .join(' | ');
          errorMsg = '$errorMsg — $fields';
        }
      }
      throw ApiException(
        errorMsg,
        statusCode: r.statusCode,
        field: field,
        code: code,
      );
    }
    if (d is! Map<String, dynamic>) {
      throw ApiException(
        'Invalid response from server (HTTP ${r.statusCode}). Body: ${r.body.length > 200 ? r.body.substring(0, 200) : r.body}',
        statusCode: r.statusCode,
      );
    }
    return d;
  }
}
