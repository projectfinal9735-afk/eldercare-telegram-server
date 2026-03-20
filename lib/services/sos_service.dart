import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

import 'live_location_service.dart';
import 'telegram_notification_service.dart';

class SosService {
  SosService._();
  static final SosService instance = SosService._();

  final _db = FirebaseFirestore.instance;

  Future<void> createSOS({required LatLng point}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final profile = await _db.collection('users').doc(uid).get();
    final elderName = (profile.data()?['fullName'] ?? '').toString();

    await _db.collection('sos_requests').add({
      'elderId': uid,
      'elderName': elderName,
      'lat': point.latitude,
      'lng': point.longitude,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });

    await LiveLocationService.instance.saveHistoryPoint(
      lat: point.latitude,
      lng: point.longitude,
      elderName: elderName,
      source: 'sos',
    );

    await TelegramNotificationService.instance.queueForMyCaregivers(
      type: 'sos',
      title: '🚨 SOS',
      body: elderName.isEmpty
          ? 'ผู้สูงอายุต้องการความช่วยเหลือ'
          : '$elderName ต้องการความช่วยเหลือ',
      point: point,
    );
  }
}
