import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> points;
  final double? distanceMeters;
  final double? durationSeconds;

  const RouteResult({
    required this.points,
    this.distanceMeters,
    this.durationSeconds,
  });
}

class RouteService {
  static Future<RouteResult> getRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '${end.longitude},${end.latitude}'
      '?overview=full&geometries=geojson&steps=false',
    );

    final res = await http.get(uri, headers: {
      'User-Agent': 'elder-care-app/1.0',
    });

    if (res.statusCode != 200) {
      throw Exception('โหลดเส้นทางไม่สำเร็จ (${res.statusCode})');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final routes = (data['routes'] as List<dynamic>? ?? []);
    if (routes.isEmpty) {
      throw Exception('ไม่พบเส้นทาง');
    }

    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>?;
    final coords = (geometry?['coordinates'] as List<dynamic>? ?? []);
    final points = coords
        .whereType<List>()
        .where((c) => c.length >= 2)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();

    return RouteResult(
      points: points,
      distanceMeters: (route['distance'] as num?)?.toDouble(),
      durationSeconds: (route['duration'] as num?)?.toDouble(),
    );
  }
}
