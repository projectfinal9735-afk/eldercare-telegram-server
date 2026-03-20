import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  StreamSubscription<Position>? _positionSub;

  Future<LatLng> getCurrentLatLng() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('กรุณาเปิด GPS ก่อน');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('ไม่ได้รับอนุญาตให้ใช้ตำแหน่ง');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('ไม่ได้รับอนุญาตให้ใช้ตำแหน่ง');
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    return LatLng(pos.latitude, pos.longitude);
  }

  Future<void> startTracking({
    required Future<void> Function(Position position) onPosition,
  }) async {
    await stopTracking();
    await getCurrentLatLng();

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen(onPosition);
  }

  Future<void> stopTracking() async {
    await _positionSub?.cancel();
    _positionSub = null;
  }

  bool get isTracking => _positionSub != null;
}
