import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const String _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
const String _androidEmulatorHost = 'http://10.0.2.2:3000';
const String _androidUsbReverseHost = 'http://127.0.0.1:3000';
const String _lanHost = 'http://192.168.160.1:3000';
const String _localhostHost = 'http://localhost:3000';
const Duration requestTimeout = Duration(seconds: 12);
const Duration uploadTimeout = Duration(seconds: 60);

String apiBaseUrlForDisplay() {
  return _configuredBaseUrl.isNotEmpty ? _configuredBaseUrl : primaryApiHost();
}

String apiConnectionHint() {
  final hosts = _candidateHosts();
  return 'API yang dipakai: ${apiBaseUrlForDisplay()}. Coba host: ${hosts.join(' / ')}. Jika pakai HP fisik via USB, jalankan adb reverse tcp:3000 tcp:3000 atau set API_BASE_URL ke IP laptop.';
}

String primaryApiHost() {
  if (_configuredBaseUrl.isNotEmpty) {
    return _configuredBaseUrl;
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

  Exception? lastError;

  for (final host in hosts) {
    try {
      return await http
          .post(
            Uri.parse('$host$path'),
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
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

  Exception? lastError;

  for (final host in hosts) {
    try {
      return await http
          .get(
            Uri.parse('$host$path'),
            headers: const {'Content-Type': 'application/json'},
          )
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

  Exception? lastError;

  for (final host in hosts) {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$host/items'));
      request.fields.addAll(fields);

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
  if (_configuredBaseUrl.isNotEmpty) {
    return <String>[_configuredBaseUrl];
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
  if (_configuredBaseUrl.isNotEmpty) {
    return _configuredBaseUrl;
  }

  if (kIsWeb) {
    return _localhostHost;
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    return _androidUsbReverseHost;
  }

  return primaryApiHost();
}
