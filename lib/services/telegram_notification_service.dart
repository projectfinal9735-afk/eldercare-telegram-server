import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class TelegramNotificationService {
  TelegramNotificationService._();
  static final TelegramNotificationService instance = TelegramNotificationService._();

  static const String _baseUrl = 'https://eldercare-telegram-server.onrender.com';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> queueForMyCaregivers({
    required String type,
    required String title,
    required String body,
    required LatLng point,
    Map<String, dynamic>? extra,
  }) async {
    final elderUid = FirebaseAuth.instance.currentUser?.uid;
    if (elderUid == null) return;

    final elderSnap = await _db.collection('users').doc(elderUid).get();
    final elderData = elderSnap.data() ?? <String, dynamic>{};
    final caregiverIds = (elderData['caregiverIds'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (caregiverIds.isEmpty) {
      throw Exception('ยังไม่มีผู้ดูแลที่เชื่อมไว้');
    }

    final futures = caregiverIds.map(
      (caregiverUid) => _sendAlert(
        caregiverUid: caregiverUid,
        elderUid: elderUid,
        type: type,
        title: title,
        body: body,
        point: point,
        extra: extra,
      ),
    );

    final results = await Future.wait(futures, eagerError: false);
    final successCount = results.where((ok) => ok).length;

    if (successCount == 0) {
      throw Exception('ส่ง Telegram ไม่สำเร็จ');
    }
  }

  Future<bool> _sendAlert({
    required String caregiverUid,
    required String elderUid,
    required String type,
    required String title,
    required String body,
    required LatLng point,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/send-alert'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': caregiverUid,
          'elderUid': elderUid,
          'type': type,
          'title': title,
          'body': body,
          'lat': point.latitude,
          'lng': point.longitude,
          'extra': extra ?? <String, dynamic>{},
        }),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
