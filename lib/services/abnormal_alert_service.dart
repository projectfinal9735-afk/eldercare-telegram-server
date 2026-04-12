import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

import 'telegram_notification_service.dart';

class AbnormalAlertService {
  AbnormalAlertService._();

  static final AbnormalAlertService instance = AbnormalAlertService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> onLocationUpdated({
    required double lat,
    required double lng,
    String? elderName,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final geofenceDoc = await _db
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('geofence')
          .get();
      final geofence = geofenceDoc.data() ?? <String, dynamic>{};
      final enabled = geofence['enabled'] == true;
      final centerLat = (geofence['centerLat'] as num?)?.toDouble();
      final centerLng = (geofence['centerLng'] as num?)?.toDouble();
      final radiusMeters = (geofence['radiusMeters'] as num?)?.toDouble() ?? 0;
      final geofenceName = (geofence['name'] ?? 'พื้นที่ปลอดภัย').toString();

      final stateRef = _db
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('alert_state');
      final stateDoc = await stateRef.get();
      final state = stateDoc.data() ?? <String, dynamic>{};
      final lastGeofenceStatus = (state['geofenceStatus'] ?? 'unknown').toString();

      if (!enabled || centerLat == null || centerLng == null || radiusMeters <= 0) {
        await stateRef.set({
          'geofenceStatus': 'disabled',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      final distance = _distanceMeters(
        lat1: lat,
        lng1: lng,
        lat2: centerLat,
        lng2: centerLng,
      );
      final isOutside = distance > radiusMeters;
      final nextStatus = isOutside ? 'outside' : 'inside';

      await stateRef.set({
        'geofenceStatus': nextStatus,
        'lastDistanceMeters': distance,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (nextStatus == lastGeofenceStatus) {
        return;
      }

      final point = LatLng(lat, lng);
      final name = elderName?.trim().isNotEmpty == true ? elderName!.trim() : 'ผู้สูงอายุ';

      if (isOutside) {
        await TelegramNotificationService.instance.queueForMyCaregivers(
          type: 'geofence_exit',
          title: '🚧 ออกนอกพื้นที่ปลอดภัย',
          body: '$name ออกจาก $geofenceName แล้ว',
          point: point,
          extra: {
            'geofence_name': geofenceName,
            'distance_meters': distance.round(),
            'radius_meters': radiusMeters.round(),
          },
        );
      } else if (lastGeofenceStatus == 'outside') {
        await TelegramNotificationService.instance.queueForMyCaregivers(
          type: 'geofence_enter',
          title: '✅ กลับเข้าพื้นที่ปลอดภัย',
          body: '$name กลับเข้า $geofenceName แล้ว',
          point: point,
          extra: {
            'geofence_name': geofenceName,
            'distance_meters': distance.round(),
            'radius_meters': radiusMeters.round(),
          },
        );
      }
    } catch (_) {
      // ไม่ให้ระบบแจ้งเตือนทำให้การอัปเดตตำแหน่งล้ม
    }
  }

  Future<void> onSharingStopped({
    double? lat,
    double? lng,
    String? elderName,
  }) async {
    if (lat == null || lng == null) return;

    try {
      final name = elderName?.trim().isNotEmpty == true ? elderName!.trim() : 'ผู้สูงอายุ';
      await TelegramNotificationService.instance.queueForMyCaregivers(
        type: 'live_stopped',
        title: '🛑 หยุดแชร์ตำแหน่งสด',
        body: '$name หยุดแชร์ตำแหน่งสดแล้ว',
        point: LatLng(lat, lng),
      );
    } catch (_) {
      // ignore
    }
  }

  double _distanceMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLng = (lng2 - lng1) * pi / 180.0;
    final a =
        (0.5 - (cos(dLat) / 2)) +
        cos(lat1 * pi / 180.0) *
            cos(lat2 * pi / 180.0) *
            (0.5 - (cos(dLng) / 2));
    return earthRadius * 2 * asin(sqrt(a));
  }
}
