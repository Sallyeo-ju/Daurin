import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';

const Map<String, String> _knownOngkirAreaCodes = {
  'jabodetabek': '31555',
  'west jakarta': '31555',
  'jakarta barat': '31555',
  'central jakarta': '31555',
  'jakarta pusat': '31555',
  'east jakarta': '31555',
  'jakarta timur': '31555',
  'south jakarta': '31555',
  'jakarta selatan': '31555',
  'north jakarta': '31555',
  'jakarta utara': '31555',
};

String resolveOngkirAreaCode(String locationText, {required String fallback}) {
  final normalized = locationText.trim().toLowerCase();
  if (normalized.isEmpty) {
    return fallback;
  }

  final codeMatch = RegExp(r'\b\d{5}\b').firstMatch(normalized);
  if (codeMatch != null) {
    return codeMatch.group(0)!;
  }

  for (final entry in _knownOngkirAreaCodes.entries) {
    if (normalized.contains(entry.key)) {
      return entry.value;
    }
  }

  return fallback;
}

class OngkirService {
  // Fungsi ini sekarang mengembalikan Future<int> (mengembalikan angka nominal ongkir)
  Future<int> fetchOngkir({
    String origin = '31555',
    String destination = '68423',
    String courier = 'jne',
    String price = 'lowest',
    int weight = 1000,
  }) async {
    final String url = buildApiUrl('/api/cek-ongkir');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'origin': origin,
          'destination': destination,
          'courier': courier,
          'price': price,
          'weight': weight,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final int biayaOngkir = responseData is Map<String, dynamic>
            ? (responseData['cost'] as int? ?? 0)
            : 0;
        return biayaOngkir;
      } else {
        debugPrint('Server error status: ${response.statusCode}');
        return 5000; // Nilai default jika server backend bermasalah
      }
    } catch (error) {
      debugPrint('Terjadi kesalahan koneksi: $error');
      return 5000; // Nilai default jika koneksi gagal / server mati
    }
  }
}
