import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:signfix_app/services/api_client.dart';

class MockHttpClient extends http.BaseClient {
  MockHttpClient(
      {this.body = '{"ok":true}', this.contentType = 'application/json'});

  final String body;
  final String contentType;
  final List<http.BaseRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    await request.finalize().drain<void>();
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': contentType},
    );
  }
}

void main() {
  test('requestQuotationChanges uses the backend action contract', () async {
    final client = MockHttpClient();
    final api = ApiClient(baseUrl: 'https://example.com', httpClient: client);

    await api.requestQuotationChanges('Q-123', 'Please adjust layout');

    expect(client.requests.length, 1);
    final request = client.requests.single as http.Request;
    expect(request.method, 'POST');
    expect(request.url.path, '/customer/quotations/Q-123/action');
    final body = jsonDecode(request.body);
    expect(body['action'], 'request_changes');
    expect(body['notes'], 'Please adjust layout');
  });

  test('orderOptions requests the customer options endpoint', () async {
    final client = MockHttpClient(
      body: jsonEncode({
        'data': {
          'units': ['ft', 'in', 'cm', 'm'],
        },
      }),
    );
    final api = ApiClient(baseUrl: 'https://example.com', httpClient: client);

    final options = await api.orderOptions();

    expect(client.requests.single.url.path, '/customer/order-options');
    expect(options['units'], ['ft', 'in', 'cm', 'm']);
  });

  test('orderDetail uses the customer order route', () async {
    final client = MockHttpClient();
    final api = ApiClient(baseUrl: 'https://example.com', httpClient: client);

    await api.orderDetail('SB-ORD-2026-000042');

    expect(client.requests.single.method, 'GET');
    expect(
        client.requests.single.url.path, '/customer/orders/SB-ORD-2026-000042');
  });

  test('quotationPdf requests the authenticated PDF endpoint', () async {
    final client = MockHttpClient(
      body: 'pdf-bytes',
      contentType: 'application/pdf',
    );
    final api = ApiClient(baseUrl: 'https://example.com', httpClient: client);

    final bytes = await api.quotationPdf('SB-QUO-2026-000012');

    expect(client.requests.single.method, 'GET');
    expect(client.requests.single.url.path,
        '/customer/quotations/SB-QUO-2026-000012/pdf');
    expect(bytes, utf8.encode('pdf-bytes'));
  });

  test('uploadDesign validates and sends multipart form data', () async {
    final client = MockHttpClient(
      body: jsonEncode({'url': '/api/uploads/design.png'}),
    );
    final api = ApiClient(baseUrl: 'https://example.com', httpClient: client);
    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}signfix-test.png',
    );
    await file.writeAsBytes([1, 2, 3]);
    addTearDown(() => file.delete());

    final result = await api.uploadDesign(file);

    final request = client.requests.single;
    expect(request.url.path, '/uploads');
    expect(request.headers['content-type'], startsWith('multipart/form-data;'));
    expect(result['url'], '/api/uploads/design.png');
  });
}
