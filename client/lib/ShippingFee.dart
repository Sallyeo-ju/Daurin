import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';

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
