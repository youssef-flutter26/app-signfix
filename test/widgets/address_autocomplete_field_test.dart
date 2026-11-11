import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signfix_app/core/app_theme.dart';
import 'package:signfix_app/services/api_client.dart';
import 'package:signfix_app/widgets/address_autocomplete_field.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'https://example.test/api');

  final queries = <String>[];

  @override
  Future<List<Map<String, dynamic>>> getSavedAddresses() async => [];

  @override
  Future<List<Map<String, dynamic>>> autocompleteLocation(
    String query, {
    String? sessionToken,
    String? countryCodes,
  }) async {
    queries.add(query);
    return [
      {
        'placeId': 'place-1',
        'description': 'Delhi, India',
        'mainText': 'Delhi',
        'secondaryText': 'India',
        'provider': 'osm',
        'city': 'Delhi',
        'state': 'Delhi',
        'postcode': '110001',
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> getLocationDetails(
    String placeId, {
    String? sessionToken,
    String? provider,
    double? lat,
    double? lon,
  }) async =>
      {'formattedAddress': 'Delhi, India', 'addressLine': 'Delhi'};

  @override
  Future<Map<String, dynamic>> reverseLocation(
    double latitude,
    double longitude,
  ) async =>
      {
        'formattedAddress': 'Delhi, India',
        'addressLine': 'Delhi',
        'latitude': latitude,
        'longitude': longitude,
      };
}

void main() {
  testWidgets('searches typed places and avoids overflow on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _FakeApiClient();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AddressAutocompleteField(api: api),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'Delhi');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(api.queries, contains('Delhi'));
    expect(find.text('Delhi'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the SignFix palette for address input styling',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: AddressAutocompleteField(api: _FakeApiClient()),
        ),
      ),
    );

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(TextFormField),
        matching: find.byType(TextField),
      ),
    );
    final decoration = field.decoration!;

    expect(field.style?.color, AppColors.textBody);
    expect(decoration.fillColor, AppColors.cardBg);
    expect(decoration.labelStyle?.color, AppColors.navy);
    expect(decoration.focusedBorder, isA<OutlineInputBorder>());
    expect(
      (decoration.focusedBorder! as OutlineInputBorder).borderSide.color,
      AppColors.gold,
    );
  });

  testWidgets(
      'autofills and validates city, state, pincode, and building details',
      (tester) async {
    final api = _FakeApiClient();
    final addressKey = GlobalKey<AddressAutocompleteFieldState>();
    StructuredAddress? selectedAddress;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AddressAutocompleteField(
              key: addressKey,
              api: api,
              showRequiredRegionFields: true,
              onAddressSelected: (address) => selectedAddress = address,
            ),
          ),
        ),
      ),
    );

    final searchField = _addressField(0);
    await tester.enterText(searchField, 'Delhi');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Delhi'));
    await tester.pumpAndSettle();

    expect(_addressField(4), findsOneWidget);
    expect(_addressField(5), findsOneWidget);
    expect(_addressField(6), findsOneWidget);
    expect(selectedAddress?.city, 'Delhi');
    expect(selectedAddress?.state, 'Delhi');
    expect(selectedAddress?.pincode, '110001');
    expect(addressKey.currentState!.validateRequiredRegionFields(), isTrue);

    await tester.enterText(_addressField(1), 'Delhi');
    expect(addressKey.currentState!.validateRequiredRegionFields(), isFalse);
    await tester.pump();
    expect(
      find.text('Enter shop/house/building details, not a city or pincode.'),
      findsOneWidget,
    );

    await tester.enterText(_addressField(1), 'Shop 12');
    await tester.enterText(_addressField(6), '12345');
    expect(addressKey.currentState!.validateRequiredRegionFields(), isFalse);
    await tester.pump();
    expect(find.text('Enter a valid 6-digit pincode'), findsOneWidget);

    await tester.enterText(_addressField(6), '560001');
    expect(addressKey.currentState!.validateRequiredRegionFields(), isTrue);
    expect(selectedAddress!.toMap()['city'], 'Delhi');
    expect(selectedAddress!.toMap()['state'], 'Delhi');
    expect(selectedAddress!.toMap()['pincode'], '560001');
    expect(tester.takeException(), isNull);
  });
}

Finder _addressField(int index) => find.byType(TextFormField).at(index);
