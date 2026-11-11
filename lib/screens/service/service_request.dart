import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';

class ServiceRequest extends StatefulWidget {
  const ServiceRequest({super.key, required this.api});
  final ApiClient api;
  @override
  State<ServiceRequest> createState() => _ServiceRequestState();
}

class _ServiceRequestState extends State<ServiceRequest> {
  final _desc = TextEditingController();
  final _address = TextEditingController();
  String _category = 'LED Problem';
  final _photos = <File>[];
  Position? _position;
  bool _loading = false;
  bool _gpsLoading = false;

  static const _categories = [
    'LED Problem',
    'Electrical Issue',
    'Physical Damage',
    'Sign Board Repair',
    'Replacement',
    'Installation',
    'Cleaning',
    'Maintenance',
    'Inspection',
    'Emergency',
    'Other',
  ];

  @override
  void dispose() {
    _desc.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final file =
        await ImagePicker().pickImage(source: source, imageQuality: 78);
    if (file != null && mounted) setState(() => _photos.add(File(file.path)));
  }

  /// Get GPS coordinates AND reverse-geocode to human address
  Future<void> _captureLocation() async {
    setState(() => _gpsLoading = true);
    try {
      // 1. Check & request permission
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) showAppError(context, 'Location permission is required.');
        return;
      }

      // 2. Get coordinates — cross-platform, high accuracy, fresh (not cached)
      final LocationSettings locationSettings;
      if (Platform.isAndroid) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          forceLocationManager: false,
          timeLimit: const Duration(seconds: 15),
        );
      } else if (Platform.isIOS || Platform.isMacOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.high,
          activityType: ActivityType.other,
          timeLimit: const Duration(seconds: 15),
          pauseLocationUpdatesAutomatically: false,
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        );
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      // 3. Reverse geocode using OpenStreetMap Nominatim (free, no API key)
      final addressText = await _reverseGeocode(pos.latitude, pos.longitude);

      if (mounted) {
        setState(() {
          _position = pos;
          // ✅ Fill address field with human-readable address
          if (addressText.isNotEmpty) {
            _address.text = addressText;
          }
        });
        // Show success snack
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.location_on_rounded,
                color: AppColors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
                child: Text(addressText.isNotEmpty
                    ? 'Location captured: $addressText'
                    : 'GPS location captured (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})')),
          ]),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) showAppError(context, e);
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  /// Reverse geocode using OpenStreetMap Nominatim API (free, no key needed)
  Future<String> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1',
      );
      final res = await http.get(uri, headers: {
        'User-Agent': 'SignFix/1.0 (signfix@app.com)',
        'Accept-Language': 'en',
      }).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>? ?? {};

        // Build readable address from components
        final parts = <String>[];
        final houseNo = addr['house_number']?.toString() ?? '';
        final road =
            addr['road']?.toString() ?? addr['pedestrian']?.toString() ?? '';
        final suburb = addr['suburb']?.toString() ??
            addr['neighbourhood']?.toString() ??
            '';
        final city = addr['city']?.toString() ??
            addr['town']?.toString() ??
            addr['village']?.toString() ??
            '';
        final state = addr['state']?.toString() ?? '';
        final postcode = addr['postcode']?.toString() ?? '';
        final country = addr['country']?.toString() ?? '';

        if (road.isNotEmpty) {
          parts.add(houseNo.isNotEmpty ? '$houseNo $road' : road);
        }
        if (suburb.isNotEmpty) parts.add(suburb);
        if (city.isNotEmpty) parts.add(city);
        if (state.isNotEmpty) parts.add(state);
        if (postcode.isNotEmpty) parts.add(postcode);
        if (country.isNotEmpty) parts.add(country);

        return parts.join(', ');
      }
    } catch (_) {
      // Network error — return empty, user can type manually
    }
    return '';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_desc.text.trim().isEmpty) {
      showAppError(
          context, 'Please describe the problem with your sign board.');
      return;
    }
    if (_desc.text.trim().length < 10) {
      showAppError(context, 'Description must be at least 10 characters.');
      return;
    }
    if (_address.text.trim().isEmpty) {
      showAppError(
          context, 'Please enter the sign board address or use GPS location.');
      return;
    }
    if (_photos.isEmpty) {
      showAppError(context, 'Please add at least 1 photo of the problem.');
      return;
    }

    setState(() => _loading = true);
    try {
      final urls = <String>[];
      for (final file in _photos) {
        final result = await widget.api.upload(file, 'service');
        if (result['url'] != null) urls.add(result['url'].toString());
      }
      final result = await widget.api.createService({
        'category': _category,
        'description': _desc.text.trim(),
        'address': _address.text.trim(),
        'latitude': _position?.latitude,
        'longitude': _position?.longitude,
        'photos': urls,
      });
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.navyDark,
          icon: const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 52),
          title: const Text('Request Submitted!',
              style: TextStyle(color: AppColors.white)),
          content: Text(
            '${result['message'] ?? 'Your request has been received.'}\n\nTicket: ${result['id'] ?? ''}',
            style: const TextStyle(color: AppColors.textLight),
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'))
          ],
        ),
      );
      if (mounted) {
        _desc.clear();
        _address.clear();
        setState(() {
          _photos.clear();
          _position = null;
        });
      }
    } catch (e) {
      if (mounted) showAppError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // Heading
          const Text('Request a service',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          const SizedBox(height: 4),
          const Text('Photo → problem → location → submit',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 20),

          // Photo picker row
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Camera'),
            )),
            const SizedBox(width: 10),
            Expanded(
                child: OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
            )),
          ]),
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            // Photo thumbnails
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(_photos[i],
                        width: 80, height: 80, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => setState(() => _photos.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                            color: AppColors.danger, shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            size: 12, color: AppColors.white),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Category dropdown
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'Problem category',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            dropdownColor: AppColors.white,
            style: const TextStyle(color: AppColors.navy),
            items: _categories
                .map((x) => DropdownMenuItem(
                      value: x,
                      child: Text(
                        x,
                        style: const TextStyle(color: AppColors.navy),
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 12),

          // Description
          TextField(
            controller: _desc,
            maxLines: 4,
            style: const TextStyle(color: AppColors.charcoal),
            decoration: const InputDecoration(
              labelText: 'Describe the problem *',
              hintText: 'e.g. LED panel flickering, sign board broken...',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.description_outlined),
            ),
          ),
          const SizedBox(height: 12),

          // Address field — editable, auto-filled by GPS
          TextField(
            controller: _address,
            maxLines: 2,
            style: const TextStyle(color: AppColors.charcoal),
            decoration: InputDecoration(
              labelText: 'Address *',
              hintText: 'Enter address or use GPS below',
              prefixIcon: const Icon(Icons.location_on_outlined),
              // Show clear button when address is filled
              suffixIcon: _address.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: AppColors.textMuted, size: 18),
                      onPressed: () {
                        setState(() {
                          _address.clear();
                          _position = null;
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),

          // GPS button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _gpsLoading ? null : _captureLocation,
              icon: _gpsLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.gold))
                  : Icon(
                      _position == null
                          ? Icons.my_location_rounded
                          : Icons.check_circle_outline_rounded,
                      color: _position == null
                          ? AppColors.gold
                          : AppColors.success,
                    ),
              label: Text(
                _gpsLoading
                    ? 'Getting location…'
                    : _position == null
                        ? 'Use GPS location'
                        : 'GPS location captured  (tap to refresh)',
                style: TextStyle(
                  color: _position == null ? AppColors.gold : AppColors.success,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: _position == null
                      ? AppColors.gold.withValues(alpha: .5)
                      : AppColors.success.withValues(alpha: .5),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),

          // GPS coordinates display
          if (_position != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.gps_fixed, size: 13, color: AppColors.success),
              const SizedBox(width: 6),
              Text(
                'GPS: ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 11, color: AppColors.success),
              ),
            ]),
          ],

          const SizedBox(height: 20),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: LoadingButton(
              loading: _loading,
              onPressed: _submit,
              child: const Text('Submit service request'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
}
