import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class TelegramNotificationService {
  TelegramNotificationService._();
  static final TelegramNotificationService instance = TelegramNotificationService._();

  static const String _baseUrl = String.fromEnvironment(
    'LINE_SERVER_BASE_URL',
    defaultValue: 'https://eldercare-telegram-server.onrender.com',
  );
  static const Duration _timeout = Duration(seconds: 15);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> queueForMyCaregivers({
    required String type,
    required String title,
    required String body,
    required LatLng point,
    Map<String, dynamic>? extra,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final elderSnap = await _db.collection('users').doc(uid).get();
    final elderData = elderSnap.data() ?? <String, dynamic>{};

    final rawCaregiverIds = elderData['caregiverIds'];
    List<String> caregiverIds = <String>[];

    if (rawCaregiverIds is List) {
      caregiverIds = rawCaregiverIds
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (rawCaregiverIds is String && rawCaregiverIds.isNotEmpty) {
      caregiverIds = <String>[rawCaregiverIds];
    }

    if (caregiverIds.isEmpty) {
      return;
    }

    final caregiverDocs = await Future.wait(
      caregiverIds.map((id) => _db.collection('users').doc(id).get()),
    );

    final recipients = caregiverDocs
        .where((doc) => doc.exists)
        .map((doc) => <String, dynamic>{
              'caregiverId': doc.id,
              'lineUserId': (doc.data()?['lineUserId'] ?? '').toString(),
              'lineConnected': (doc.data()?['lineConnected'] ?? false) == true,
            })
        .where((item) =>
            (item['lineConnected'] as bool) == true &&
            (item['lineUserId'] as String).isNotEmpty)
        .toList();

    final payload = <String, dynamic>{
      'elderId': uid,
      'elderName': (elderData['fullName'] ?? '').toString(),
      'caregiverIds': caregiverIds,
      'lineUserIds': recipients.map((e) => e['lineUserId']).toList(),
      'recipients': recipients,
      'type': type,
      'title': title,
      'body': body,
      'lat': point.latitude,
      'lng': point.longitude,
      'extra': extra ?? <String, dynamic>{},
    };

    final uri = Uri.parse('${_baseUrl.replaceAll(RegExp(r'/+$'), '')}/send-alert');
    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('แจ้งเตือนไม่สำเร็จ (${response.statusCode}) ${response.body}');
    }
  }
}

// Backward-compatible alias so updated LINE call sites can keep using
// LINENotificationService while the file/class name remains unchanged.
class LINENotificationService {
  LINENotificationService._();

  static TelegramNotificationService get instance => TelegramNotificationService.instance;
}
