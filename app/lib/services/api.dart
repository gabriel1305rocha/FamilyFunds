import 'dart:convert';

import 'package:http/http.dart' as http;

/// URL da API. Altere com: flutter run --dart-define=API_URL=http://10.0.2.2:3000/api
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000/api');

class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, this.baseUrl = apiUrl}) : _http = client ?? http.Client();

  final http.Client _http;
  final String baseUrl;
  String? token;

  /// Chamado quando a API responde 401 (token expirado).
  void Function()? onUnauthorized;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final q = query?..removeWhere((_, v) => v == null);
    return Uri.parse('$baseUrl$path').replace(queryParameters: q?.map((k, v) => MapEntry(k, '$v')));
  }

  Future<dynamic> get(String path, [Map<String, dynamic>? query]) => _send(() => _http.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, Object body) =>
      _send(() => _http.post(_uri(path), headers: _headers, body: jsonEncode(body)));

  Future<dynamic> patch(String path, Object body) =>
      _send(() => _http.patch(_uri(path), headers: _headers, body: jsonEncode(body)));

  Future<dynamic> delete(String path, [Map<String, dynamic>? query]) =>
      _send(() => _http.delete(_uri(path, query), headers: _headers));

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response res;
    try {
      res = await request();
    } catch (_) {
      throw ApiException(0, 'Não foi possível conectar ao servidor');
    }
    final body = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    if (res.statusCode == 401 && token != null) onUnauthorized?.call();
    var message = (body is Map && body['error'] is String) ? body['error'] as String : 'Erro ${res.statusCode}';
    if (body is Map && body['details'] is List && (body['details'] as List).isNotEmpty) {
      final first = (body['details'] as List).first;
      if (first is Map && first['message'] != null) message = '$message: ${first['message']}';
    }
    throw ApiException(res.statusCode, message);
  }
}
