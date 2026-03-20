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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final elderSnap = await _db.collection('users').doc(uid).get();
    final elderData = elderSnap.data() ?? <String, dynamic>{};
    final caregiverIds = (elderData['caregiverIds'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();

    if (caregiverIds.isEmpty) return;

    final payload = <String, dynamic>{
      'elderId': uid,
      'elderName': (elderData['fullName'] ?? '').toString(),
      'caregiverIds': caregiverIds,
      'type': type,
      'title': title,
      'body': body,
      'lat': point.latitude,
      'lng': point.longitude,
      'extra': extra ?? <String, dynamic>{},
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/send-alert'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Telegram alert failed: ${response.statusCode} ${response.body}');
    }
  }
}
