import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PoiResult {
  final String name;
  final LatLng point;

  const PoiResult({required this.name, required this.point});
}

class PoiService {
  static Future<List<PoiResult>> search({
    required String label,
    required String query,
  }) async {
    final uri = Uri.parse('https://overpass-api.de/api/interpreter');
    final res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'User-Agent': 'elder-care-app/1.0',
          },
          body: {'data': query},
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('ค้นหา$labelไม่สำเร็จ (${res.statusCode})');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final elements = (data['elements'] as List<dynamic>? ?? []);
    final pois = <PoiResult>[];
    for (final e in elements) {
      final osmType = (e['type'] ?? '').toString();
      final tags = (e['tags'] as Map<String, dynamic>?) ?? {};
      final name = (tags['name'] ?? tags['name:th'] ?? label).toString().trim();

      double? lat;
      double? lon;
      if (osmType == 'node') {
        lat = (e['lat'] as num?)?.toDouble();
        lon = (e['lon'] as num?)?.toDouble();
      } else {
        final center = (e['center'] as Map<String, dynamic>?) ?? {};
        lat = (center['lat'] as num?)?.toDouble();
        lon = (center['lon'] as num?)?.toDouble();
      }

      if (lat == null || lon == null) continue;
      pois.add(PoiResult(name: name.isEmpty ? label : name, point: LatLng(lat, lon)));
    }
    return pois;
  }
}
