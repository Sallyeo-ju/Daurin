import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
const String _defaultHostedBaseUrl = 'https://daurin-production.up.railway.app';
const String _androidEmulatorHost = 'http://10.0.2.2:3000';
const String _androidUsbReverseHost = 'http://127.0.0.1:3000';
const String _lanHost = 'http://192.168.160.1:3000';
const String _localhostHost = 'http://localhost:3000';
const String _authTokenKey = 'auth_token';
const Duration requestTimeout = Duration(seconds: 12);
const Duration uploadTimeout = Duration(seconds: 60);

String _resolvedBaseUrl() {
  if (_configuredBaseUrl.isNotEmpty) {
    return _configuredBaseUrl;
  }
  return _defaultHostedBaseUrl;
}

String apiBaseUrlForDisplay() {
  final baseUrl = _resolvedBaseUrl();
  if (baseUrl.isNotEmpty) {
    return baseUrl;
  }
  return kReleaseMode ? 'API_BASE_URL belum diset' : primaryApiHost();
}

String apiConnectionHint() {
  final hosts = _candidateHosts();
  if (kReleaseMode) {
    return 'API release: ${apiBaseUrlForDisplay()}. Pastikan API_BASE_URL di-set ke HTTPS production backend.';
  }
  return 'API yang dipakai: ${apiBaseUrlForDisplay()}. Coba host: ${hosts.join(' / ')}. Jika pakai HP fisik via USB, jalankan adb reverse tcp:3000 tcp:3000 atau set API_BASE_URL ke IP laptop.';
}

String primaryApiHost() {
  final baseUrl = _resolvedBaseUrl();
  if (baseUrl.isNotEmpty) {
    return baseUrl;
  }

  if (kReleaseMode) {
    throw StateError(
      'API_BASE_URL belum diset. Release build harus memakai backend production HTTPS.',
    );
  }

  if (kIsWeb) {
    return _localhostHost;
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    return _androidEmulatorHost;
  }

  return _localhostHost;
}

String buildApiUrl(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  if (kReleaseMode && _resolvedBaseUrl().isEmpty) {
    throw StateError(
      'API_BASE_URL belum diset. Release build harus memakai backend production HTTPS.',
    );
  }
  if (path.startsWith('/')) {
    return '${_mediaApiHost()}$path';
  }
  return '${_mediaApiHost()}/$path';
}

Future<http.Response> postJsonWithFallback({
  required String path,
  required String body,
}) async {
  final hosts = _candidateHosts();
  final headers = await _jsonHeaders();

  Exception? lastError;

  for (final host in hosts) {
    try {
      return await http
          .post(Uri.parse('$host$path'), headers: headers, body: body)
          .timeout(requestTimeout);
    } on Exception catch (error) {
      lastError = error;
    }
  }

  throw Exception(
    '${lastError ?? Exception('Unable to reach server')}. ${apiConnectionHint()}',
  );
}

Future<http.Response> getJsonWithFallback({required String path}) async {
  final hosts = _candidateHosts();
  final headers = await _jsonHeaders();

  Exception? lastError;

  for (final host in hosts) {
    try {
      return await http
          .get(Uri.parse('$host$path'), headers: headers)
          .timeout(requestTimeout);
    } on Exception catch (error) {
      lastError = error;
    }
  }

  throw Exception(
    '${lastError ?? Exception('Unable to reach server')}. ${apiConnectionHint()}',
  );
}

Future<http.Response> patchJsonWithFallback({
  required String path,
  required String body,
}) async {
  final hosts = _candidateHosts();
  final headers = await _jsonHeaders();

  Exception? lastError;

  for (final host in hosts) {
    try {
      return await http
          .patch(Uri.parse('$host$path'), headers: headers, body: body)
          .timeout(requestTimeout);
    } on Exception catch (error) {
      lastError = error;
    }
  }

  throw Exception(
    '${lastError ?? Exception('Unable to reach server')}. ${apiConnectionHint()}',
  );
}

Future<http.Response> deleteJsonWithFallback({required String path}) async {
  final hosts = _candidateHosts();
  final headers = await _jsonHeaders();

  Exception? lastError;

  for (final host in hosts) {
    try {
      return await http
          .delete(Uri.parse('$host$path'), headers: headers)
          .timeout(requestTimeout);
    } on Exception catch (error) {
      lastError = error;
    }
  }

  throw Exception(
    '${lastError ?? Exception('Unable to reach server')}. ${apiConnectionHint()}',
  );
}

Future<http.Response> postMultipartItemWithFallback({
  required Map<String, String> fields,
  String? photoPath,
}) async {
  final hosts = _candidateHosts();
  final authHeaders = await _authHeaders();

  Exception? lastError;

  for (final host in hosts) {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$host/items'));
      request.fields.addAll(fields);
      request.headers.addAll(authHeaders);

      if (photoPath != null && photoPath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('photo', photoPath),
        );
      }

      final streamed = await request.send().timeout(uploadTimeout);
      return http.Response.fromStream(streamed);
    } on Exception catch (error) {
      lastError = error;
    }
  }

  throw Exception(
    '${lastError ?? Exception('Unable to reach server')}. ${apiConnectionHint()}',
  );
}

List<String> _candidateHosts() {
  final baseUrl = _resolvedBaseUrl();
  if (baseUrl.isNotEmpty) {
    return <String>[baseUrl];
  }

  if (kReleaseMode) {
    return <String>[];
  }

  if (kIsWeb) {
    return <String>[_localhostHost];
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    return <String>[
      _androidEmulatorHost,
      _androidUsbReverseHost,
      _lanHost,
      _localhostHost,
    ];
  }

  return <String>[_localhostHost, _lanHost];
}

String _mediaApiHost() {
  final baseUrl = _resolvedBaseUrl();
  if (baseUrl.isNotEmpty) {
    return baseUrl;
  }

  if (kReleaseMode) {
    throw StateError(
      'API_BASE_URL belum diset. Release build harus memakai backend production HTTPS.',
    );
  }

  if (kIsWeb) {
    return _localhostHost;
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    return _androidUsbReverseHost;
  }

  return primaryApiHost();
}

Future<Map<String, String>> _jsonHeaders() async {
  final headers = <String, String>{'Content-Type': 'application/json'};
  headers.addAll(await _authHeaders());
  return headers;
}

Future<Map<String, String>> _authHeaders() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(_authTokenKey)?.trim();
  if (token == null || token.isEmpty) {
    return <String, String>{};
  }

  return <String, String>{'Authorization': 'Bearer $token'};
}

Future<void> saveAuthToken(String? token) async {
  final prefs = await SharedPreferences.getInstance();
  final normalizedToken = token?.trim() ?? '';
  if (normalizedToken.isEmpty) {
    await prefs.remove(_authTokenKey);
  } else {
    await prefs.setString(_authTokenKey, normalizedToken);
  }
}

Future<String?> getAuthToken() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(_authTokenKey)?.trim();
  if (token == null || token.isEmpty) {
    return null;
  }
  return token;
}
