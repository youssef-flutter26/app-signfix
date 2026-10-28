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
}
