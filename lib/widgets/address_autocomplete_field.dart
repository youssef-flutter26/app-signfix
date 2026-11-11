import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../core/app_theme.dart';
import '../services/api_client.dart';

class StructuredAddress {
  StructuredAddress({
    this.formattedAddress = '',
    this.addressLine = '',
    this.building = '',
    this.floor = '',
    this.landmark = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.country = '',
    this.latitude,
    this.longitude,
    this.placeId,
    this.instructions = '',
    this.label = 'Delivery',
    this.saveToProfile = false,
  });

  String formattedAddress;
  String addressLine;
  String building;
  String floor;
  String landmark;
  String city;
  String state;
  String pincode;
  String country;
  double? latitude;
  double? longitude;
  String? placeId;
  String instructions;
  String label;
  bool saveToProfile;

  String get fullDisplayAddress {
    final parts = <String>[];
    if (building.isNotEmpty) parts.add(building);
    if (floor.isNotEmpty) parts.add(floor);
    if (addressLine.isNotEmpty && !parts.contains(addressLine)) {
      parts.add(addressLine);
    } else if (formattedAddress.isNotEmpty && parts.isEmpty) {
      parts.add(formattedAddress);
    }
    if (landmark.isNotEmpty) parts.add('Near $landmark');
    if (city.isNotEmpty && !parts.contains(city)) parts.add(city);
    if (state.isNotEmpty && !parts.contains(state)) parts.add(state);
    if (pincode.isNotEmpty && !parts.contains(pincode)) parts.add(pincode);
    if (country.isNotEmpty && !parts.contains(country)) parts.add(country);

    return parts.isNotEmpty ? parts.join(', ') : formattedAddress;
  }

  Map<String, dynamic> toMap() {
    return {
      'formattedAddress': fullDisplayAddress,
      'addressLine': addressLine.isNotEmpty ? addressLine : formattedAddress,
      'building': building,
      'floor': floor,
      'landmark': landmark,
      'city': city,
      'state': state,
      'pincode': pincode,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'placeId': placeId,
      'instructions': instructions,
      'label': label,
      'saveAddress': saveToProfile,
    };
  }
}

class AddressAutocompleteField extends StatefulWidget {
  const AddressAutocompleteField({
    super.key,
    required this.api,
    this.initialAddress,
    this.onAddressSelected,
    this.allowSave = true,
    this.labelText = 'Delivery / Installation Address',
    this.hintText = 'Enter street, shop, area or landmark',
    this.showExtraFields = true,
    this.showRequiredRegionFields = false,
    this.isRequired = true,
  });

  final ApiClient api;
  final String? initialAddress;
  final ValueChanged<StructuredAddress>? onAddressSelected;
  final bool allowSave;
  final String labelText;
  final String hintText;
  final bool showExtraFields;
  final bool showRequiredRegionFields;
  final bool isRequired;

  @override
  State<AddressAutocompleteField> createState() =>
      AddressAutocompleteFieldState();
}

class AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  late final TextEditingController _searchCtrl;
  final _buildingCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();

  final _focusNode = FocusNode();
  final GlobalKey _fieldKey = GlobalKey();
  final LayerLink _layerLink = LayerLink();

  Timer? _debounce;
  bool _isLoading = false;
  bool _isLocating = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _suggestions = [];
  int _searchGeneration = 0;
  bool _showOverlay = false;
  OverlayEntry? _overlayEntry;

  List<Map<String, dynamic>> _savedAddresses = [];

  late StructuredAddress _currentAddress;
  bool _extraDetailsExpanded = false;
  bool _regionValidationAttempted = false;

  @override
  void initState() {
    super.initState();
    _extraDetailsExpanded = widget.showRequiredRegionFields;
    _currentAddress = StructuredAddress(
      formattedAddress: widget.initialAddress ?? '',
      addressLine: widget.initialAddress ?? '',
    );
    _searchCtrl = TextEditingController(text: widget.initialAddress ?? '');

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _hideSuggestions();
      }
    });

    _loadSavedAddresses();
  }

  Future<void> _loadSavedAddresses() async {
    try {
      final list = await widget.api.getSavedAddresses();
      if (mounted) {
        setState(() {
          _savedAddresses = list;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _searchCtrl.dispose();
    _buildingCtrl.dispose();
    _floorCtrl.dispose();
    _landmarkCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _instructionsCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final generation = ++_searchGeneration;
    final trimmed = value.trim();

    _currentAddress.formattedAddress = trimmed;
    _currentAddress.addressLine = trimmed;
    _currentAddress.placeId = null;
    if (widget.showRequiredRegionFields) {
      _currentAddress
        ..city = ''
        ..state = ''
        ..pincode = '';
      _syncRegionControllers();
    }
    _notifyAddressChanged();
    setState(() {
      _isLoading = false;
      _errorMessage = null;
      _suggestions = [];
    });

    if (trimmed.length < 2) {
      _hideSuggestions();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchSuggestions(trimmed, generation);
    });
  }

  Future<void> _fetchSuggestions(String query, [int? generation]) async {
    if (!mounted) return;
    final requestGeneration = generation ?? ++_searchGeneration;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _showSuggestionsDropdown();

    try {
      final results = await widget.api.autocompleteLocation(query);
      if (!mounted || requestGeneration != _searchGeneration) return;

      setState(() {
        _suggestions = results;
        _isLoading = false;
      });
      _updateOverlay();
    } catch (err) {
      if (!mounted || requestGeneration != _searchGeneration) return;
      setState(() {
        _isLoading = false;
        _errorMessage = err is ApiException
            ? 'Could not load suggestions: ${err.message} Tap to retry.'
            : 'Could not load address suggestions. Check your connection and tap to retry.';
      });
      _updateOverlay();
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_isLocating) return;
    _debounce?.cancel();
    ++_searchGeneration;
    _hideSuggestions();
    setState(() {
      _isLoading = false;
      _isLocating = true;
      _errorMessage = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const ApiException('Turn on location services and try again.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const ApiException(
          'Location permission is required to use your current location.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final details = await widget.api.reverseLocation(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;

      final formattedAddress =
          details['formattedAddress']?.toString().trim() ?? '';
      final addressLine = details['addressLine']?.toString().trim() ?? '';
      if (formattedAddress.isEmpty && addressLine.isEmpty) {
        throw const ApiException(
          'Could not identify an address at your current location. You can enter it manually.',
        );
      }

      _searchCtrl.text =
          formattedAddress.isNotEmpty ? formattedAddress : addressLine;
      _currentAddress
        ..formattedAddress = _searchCtrl.text
        ..addressLine = addressLine.isNotEmpty ? addressLine : _searchCtrl.text
        ..city = details['city']?.toString() ?? ''
        ..state = details['state']?.toString() ?? ''
        ..pincode = _pincodeFrom(details)
        ..country = details['country']?.toString() ?? ''
        ..latitude = position.latitude
        ..longitude = position.longitude
        ..placeId = details['placeId']?.toString();

      _syncRegionControllers();
      _hideSuggestions();
      setState(() {});
      _notifyAddressChanged();
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : 'Could not get your current location. Check location permission and try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _selectSuggestion(Map<String, dynamic> item) async {
    final selectionGeneration = ++_searchGeneration;
    _hideSuggestions();
    final placeId = item['placeId']?.toString() ?? '';
    final provider = item['provider']?.toString();
    final description = item['description']?.toString() ?? '';

    _searchCtrl.text = description;
    _currentAddress.formattedAddress = description;
    _currentAddress.addressLine = description;
    _currentAddress.placeId = placeId;

    setState(() => _isLoading = true);
    try {
      if (placeId.isNotEmpty) {
        final details = provider == 'osm'
            ? item
            : await widget.api.getLocationDetails(placeId, provider: provider);
        if (!mounted || selectionGeneration != _searchGeneration) return;

        if (details.isNotEmpty) {
          _currentAddress.formattedAddress =
              details['formattedAddress']?.toString() ?? description;
          _currentAddress.addressLine =
              details['addressLine']?.toString() ?? description;
          _currentAddress.city = details['city']?.toString() ?? '';
          _currentAddress.state = details['state']?.toString() ?? '';
          _currentAddress.pincode = _pincodeFrom(details);
          _currentAddress.country = details['country']?.toString() ?? '';

          final lat = details['latitude'];
          final lon = details['longitude'];
          if (lat != null) _currentAddress.latitude = (lat as num).toDouble();
          if (lon != null) _currentAddress.longitude = (lon as num).toDouble();

          _searchCtrl.text = _currentAddress.formattedAddress;
          _syncRegionControllers();
        }
      }
    } catch (_) {
      if (mounted && selectionGeneration == _searchGeneration) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The location was selected, but its full address details could not be loaded.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted && selectionGeneration == _searchGeneration) {
        setState(() => _isLoading = false);
        _notifyAddressChanged();
      }
    }
  }

  void _selectSavedAddress(Map<String, dynamic> addr) {
    _debounce?.cancel();
    ++_searchGeneration;
    final addrLine = addr['addressLine']?.toString() ??
        addr['address_line']?.toString() ??
        '';
    final city = addr['city']?.toString() ?? '';
    final state = addr['state']?.toString() ?? '';
    final pincode = addr['pincode']?.toString() ?? '';

    final full = [addrLine, city, state, pincode]
        .where((s) => s.trim().isNotEmpty)
        .join(', ');

    _searchCtrl.text = full.isNotEmpty ? full : addrLine;
    _currentAddress = StructuredAddress(
      formattedAddress: full.isNotEmpty ? full : addrLine,
      addressLine: addrLine,
      city: city,
      state: state,
      pincode: pincode,
      label: addr['label']?.toString() ?? 'Saved',
    );
    _buildingCtrl.text = addr['building']?.toString() ?? '';
    _floorCtrl.text = addr['floor']?.toString() ?? '';
    _landmarkCtrl.text = addr['landmark']?.toString() ?? '';
    _instructionsCtrl.text = addr['instructions']?.toString() ?? '';
    _syncRegionControllers();

    final lat = addr['latitude'];
    final lon = addr['longitude'];
    if (lat != null) _currentAddress.latitude = (lat as num).toDouble();
    if (lon != null) _currentAddress.longitude = (lon as num).toDouble();

    _hideSuggestions();
    setState(() => _isLoading = false);
    _notifyAddressChanged();
  }

  void _notifyAddressChanged() {
    _currentAddress.building = _buildingCtrl.text.trim();
    _currentAddress.floor = _floorCtrl.text.trim();
    _currentAddress.landmark = _landmarkCtrl.text.trim();
    _currentAddress.city = _cityCtrl.text.trim();
    _currentAddress.state = _stateCtrl.text.trim();
    _currentAddress.pincode = _pincodeCtrl.text.trim();
    _currentAddress.instructions = _instructionsCtrl.text.trim();

    widget.onAddressSelected?.call(_currentAddress);
  }

  bool validateRequiredRegionFields() {
    if (!widget.showRequiredRegionFields) return true;
    setState(() => _regionValidationAttempted = true);
    final pincodeIsValid =
        RegExp(r'^\d{6}$').hasMatch(_pincodeCtrl.text.trim());
    return _cityCtrl.text.trim().isNotEmpty &&
        _stateCtrl.text.trim().isNotEmpty &&
        pincodeIsValid &&
        _buildingError == null;
  }

  String _pincodeFrom(Map<String, dynamic> details) =>
      (details['pincode'] ?? details['postcode'] ?? details['postalCode'])
          ?.toString() ??
      '';

  void _syncRegionControllers() {
    _cityCtrl.text = _currentAddress.city;
    _stateCtrl.text = _currentAddress.state;
    _pincodeCtrl.text = _currentAddress.pincode;
  }

  String? get _buildingError {
    final building = _buildingCtrl.text.trim().toLowerCase();
    if (building.isEmpty) return null;
    final locationParts = [
      _cityCtrl.text.trim().toLowerCase(),
      _stateCtrl.text.trim().toLowerCase(),
      _pincodeCtrl.text.trim().toLowerCase(),
    ];
    if (locationParts.any((part) => part.isNotEmpty && part == building)) {
      return 'Enter shop/house/building details, not a city or pincode.';
    }
    return null;
  }

  void _showSuggestionsDropdown() {
    if (_showOverlay) {
      _updateOverlay();
      return;
    }
    _showOverlay = true;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideSuggestions() {
    _showOverlay = false;
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? Size.zero;
    final anchorTop = renderBox?.localToGlobal(Offset.zero).dy ?? 0;

    return OverlayEntry(
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final availableBelow = media.size.height -
            media.viewInsets.bottom -
            anchorTop -
            size.height -
            12;
        final availableAbove = anchorTop - media.padding.top - 12;
        final showAbove =
            availableBelow < 160 && availableAbove > availableBelow;
        final availableHeight = showAbove ? availableAbove : availableBelow;
        final maxHeight = availableHeight.clamp(80.0, 260.0);

        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, showAbove ? -maxHeight - 4 : size.height + 4),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: AppColors.cardBg,
              child: Container(
                constraints: BoxConstraints(maxHeight: maxHeight),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: _buildOverlayContent(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverlayContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.gold),
            ),
            SizedBox(width: 12),
            Text('Searching live address suggestions...',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: InkWell(
          onTap: () => _fetchSuggestions(_searchCtrl.text.trim()),
          child: Row(
            children: [
              const Icon(Icons.refresh, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No matching location found. You can enter address manually.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      shrinkWrap: true,
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) =>
          const Divider(color: AppColors.cardBorder, height: 1),
      itemBuilder: (ctx, idx) {
        final item = _suggestions[idx];
        final main = item['mainText']?.toString() ?? '';
        final secondary = item['secondaryText']?.toString() ?? '';

        return Material(
          color: AppColors.cardBg,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.location_on_outlined,
                color: AppColors.gold, size: 20),
            title: Text(
              main,
              style: const TextStyle(
                  color: AppColors.textBody,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
            subtitle: secondary.isNotEmpty
                ? Text(
                    secondary,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            onTap: () => _selectSuggestion(item),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Saved Addresses Chips ──────────────────────────────────────────
        if (_savedAddresses.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.bookmark_border, color: AppColors.gold, size: 16),
              SizedBox(width: 6),
              Text(
                'Saved Addresses:',
                style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _savedAddresses.map((addr) {
                final label = addr['label']?.toString() ?? 'Address';
                final isDefault = addr['isDefault'] == true;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(
                      label.toLowerCase() == 'home'
                          ? Icons.home_outlined
                          : label.toLowerCase() == 'shop'
                              ? Icons.storefront_outlined
                              : Icons.business_outlined,
                      size: 16,
                      color: isDefault ? AppColors.navy : AppColors.gold,
                    ),
                    label: Text(label),
                    backgroundColor:
                        isDefault ? AppColors.gold : AppColors.cardBg,
                    labelStyle: TextStyle(
                      color: AppColors.navy,
                      fontSize: 12,
                      fontWeight: isDefault ? FontWeight.w700 : FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color:
                            isDefault ? AppColors.gold : AppColors.cardBorder,
                      ),
                    ),
                    onPressed: () => _selectSavedAddress(addr),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Main Search Field ──────────────────────────────────────────────
        CompositedTransformTarget(
          key: _fieldKey,
          link: _layerLink,
          child: TextFormField(
            controller: _searchCtrl,
            focusNode: _focusNode,
            style: const TextStyle(color: AppColors.textBody, fontSize: 14),
            onChanged: _onSearchChanged,
            validator: widget.isRequired
                ? (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter delivery / installation address'
                    : null
                : null,
            decoration: InputDecoration(
              labelText: widget.labelText,
              labelStyle: const TextStyle(color: AppColors.navy, fontSize: 13),
              hintText: widget.hintText,
              hintStyle: const TextStyle(
                  color: AppColors.textPlaceholder, fontSize: 13),
              filled: true,
              fillColor: AppColors.cardBg,
              prefixIcon: const Icon(Icons.search, color: AppColors.gold),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLocating || _isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.gold),
                      ),
                    ),
                  if (!_isLocating)
                    IconButton(
                      tooltip: 'Use current location',
                      icon: const Icon(Icons.my_location,
                          color: AppColors.gold, size: 19),
                      onPressed: _useCurrentLocation,
                    ),
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear,
                          color: AppColors.midGray, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                    ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
              ),
            ),
          ),
        ),

        // ── Structured Address Details Toggle ──────────────────────────────
        if (widget.showExtraFields) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              setState(() => _extraDetailsExpanded = !_extraDetailsExpanded);
            },
            child: Row(
              children: [
                Icon(
                  _extraDetailsExpanded
                      ? Icons.arrow_drop_down
                      : Icons.arrow_right,
                  color: AppColors.gold,
                  size: 20,
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    _extraDetailsExpanded
                        ? 'Hide extra delivery details'
                        : 'Add Shop/Building #, Landmark or instructions (optional)',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textLink,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          if (_extraDetailsExpanded) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _buildingCtrl,
                    style: const TextStyle(
                        color: AppColors.textBody, fontSize: 13),
                    onChanged: (_) {
                      setState(() {});
                      _notifyAddressChanged();
                    },
                    decoration: InputDecoration(
                      labelText: 'Shop / House / Building #',
                      labelStyle:
                          const TextStyle(color: AppColors.navy, fontSize: 12),
                      errorText: _buildingError,
                      filled: true,
                      fillColor: AppColors.cardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppColors.inputBorder),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _floorCtrl,
                    style: const TextStyle(
                        color: AppColors.textBody, fontSize: 13),
                    onChanged: (_) => _notifyAddressChanged(),
                    decoration: InputDecoration(
                      labelText: 'Floor / Unit',
                      labelStyle:
                          const TextStyle(color: AppColors.navy, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.cardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppColors.inputBorder),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _landmarkCtrl,
              style: const TextStyle(color: AppColors.textBody, fontSize: 13),
              onChanged: (_) => _notifyAddressChanged(),
              decoration: InputDecoration(
                labelText: 'Nearby Landmark',
                labelStyle:
                    const TextStyle(color: AppColors.navy, fontSize: 12),
                filled: true,
                fillColor: AppColors.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            if (widget.showRequiredRegionFields) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityCtrl,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(
                          color: AppColors.textBody, fontSize: 13),
                      onChanged: (_) {
                        setState(() {});
                        _notifyAddressChanged();
                      },
                      decoration: InputDecoration(
                        labelText: 'City',
                        labelStyle: const TextStyle(
                            color: AppColors.navy, fontSize: 12),
                        errorText: _regionValidationAttempted &&
                                _cityCtrl.text.trim().isEmpty
                            ? 'City is required.'
                            : null,
                        filled: true,
                        fillColor: AppColors.cardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppColors.inputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: AppColors.gold, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _stateCtrl,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(
                          color: AppColors.textBody, fontSize: 13),
                      onChanged: (_) {
                        setState(() {});
                        _notifyAddressChanged();
                      },
                      decoration: InputDecoration(
                        labelText: 'State',
                        labelStyle: const TextStyle(
                            color: AppColors.navy, fontSize: 12),
                        errorText: _regionValidationAttempted &&
                                _stateCtrl.text.trim().isEmpty
                            ? 'State is required.'
                            : null,
                        filled: true,
                        fillColor: AppColors.cardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppColors.inputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: AppColors.gold, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pincodeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: const TextStyle(color: AppColors.textBody, fontSize: 13),
                onChanged: (_) {
                  setState(() {});
                  _notifyAddressChanged();
                },
                decoration: InputDecoration(
                  labelText: 'Pincode',
                  labelStyle:
                      const TextStyle(color: AppColors.navy, fontSize: 12),
                  hintText: '6-digit pincode',
                  errorText: (_regionValidationAttempted ||
                              _pincodeCtrl.text.isNotEmpty) &&
                          !RegExp(r'^\d{6}$').hasMatch(_pincodeCtrl.text.trim())
                      ? 'Enter a valid 6-digit pincode'
                      : null,
                  filled: true,
                  fillColor: AppColors.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.gold, width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextFormField(
              controller: _instructionsCtrl,
              style: const TextStyle(color: AppColors.textBody, fontSize: 13),
              onChanged: (_) => _notifyAddressChanged(),
              decoration: InputDecoration(
                labelText: 'Delivery Instructions (optional)',
                labelStyle:
                    const TextStyle(color: AppColors.navy, fontSize: 12),
                filled: true,
                fillColor: AppColors.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            if (widget.allowSave) ...[
              const SizedBox(height: 4),
              CheckboxListTile(
                value: _currentAddress.saveToProfile,
                onChanged: (val) {
                  setState(() {
                    _currentAddress.saveToProfile = val == true;
                  });
                  _notifyAddressChanged();
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.gold,
                title: const Text(
                  'Save this delivery address to my profile',
                  style: TextStyle(color: AppColors.textBody, fontSize: 13),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ],
        ],
      ],
    );
  }
}
