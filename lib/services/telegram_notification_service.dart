import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

class TelegramNotificationService {
  TelegramNotificationService._();
  static final TelegramNotificationService instance = TelegramNotificationService._();

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

    await _db.collection('telegram_notifications').add({
      'elderId': uid,
      'type': type,
      'title': title,
      'body': body,
      'lat': point.latitude,
      'lng': point.longitude,
      'extra': extra ?? <String, dynamic>{},
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
