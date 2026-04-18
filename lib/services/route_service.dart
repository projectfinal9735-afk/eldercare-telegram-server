import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  static const Duration _timeout = Duration(seconds: 15);
  static final Map<String, ({RouteResult data, DateTime savedAt})> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 10);

  static Future<RouteResult> getRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    final cacheKey = _cacheKey(start, end);
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.savedAt) <= _cacheTtl) {
      return cached.data;
    }

    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '${end.longitude},${end.latitude}'
      '?overview=full&geometries=geojson&steps=false',
    );

    try {
      final res = await http.get(uri, headers: {
        'User-Agent': 'elder-care-app/1.0',
      }).timeout(_timeout);

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

      final result = RouteResult(
        points: points,
        distanceMeters: (route['distance'] as num?)?.toDouble(),
        durationSeconds: (route['duration'] as num?)?.toDouble(),
      );
      _cache[cacheKey] = (data: result, savedAt: DateTime.now());
      return result;
    } on TimeoutException {
      throw TimeoutException('โหลดเส้นทางใช้เวลานานเกินไป กรุณาลองใหม่');
    } on SocketException {
      throw const SocketException('ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้');
    }
  }

  static String _cacheKey(LatLng start, LatLng end) {
    String f(double value) => value.toStringAsFixed(5);
    return '${f(start.latitude)},${f(start.longitude)}:${f(end.latitude)},${f(end.longitude)}';
  }
}
