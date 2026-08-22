import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// HTTP client for authenticated server proxies.
///
/// Provider credentials stay in the server environment. The app sends only a
/// short-lived Firebase ID token to authorize the current user.
class AuthenticatedApiClient {
  AuthenticatedApiClient._();

  static Future<Map<String, String>> _headers({bool json = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요한 기능입니다.');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('인증 정보를 가져올 수 없습니다. 다시 로그인해주세요.');
    }

    return {
      'Authorization': 'Bearer $token',
      if (json) 'Content-Type': 'application/json',
    };
  }

  static Future<http.Response> get(Uri uri) async {
    return http.get(uri, headers: await _headers());
  }

  static Future<http.Response> postJson(
    Uri uri,
    Map<String, Object?> body,
  ) async {
    return http.post(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(body),
    );
  }
}
