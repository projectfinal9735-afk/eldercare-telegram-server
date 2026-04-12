import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

import 'live_location_service.dart';
import 'telegram_notification_service.dart';

class SosService {
  SosService._();
  static final SosService instance = SosService._();

  final _db = FirebaseFirestore.instance;

  Future<Map<String, String>?> getPrimaryCaregiverContact() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final elderDoc = await _db.collection('users').doc(uid).get();
    final elderData = elderDoc.data() ?? <String, dynamic>{};
    final caregiverIds = (elderData['caregiverIds'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();

    if (caregiverIds.isEmpty) return null;

    final caregiverDoc = await _db.collection('users').doc(caregiverIds.first).get();
    final caregiverData = caregiverDoc.data() ?? <String, dynamic>{};

    return {
      'name': (caregiverData['fullName'] ?? '').toString(),
      'phone': (caregiverData['phone'] ?? '').toString(),
    };
  }

  Future<void> createSOS({required LatLng point}) async {
    print('🔥 createSOS called with point: ${point.latitude}, ${point.longitude}');

    final uid = FirebaseAuth.instance.currentUser?.uid;
    print('🔥 currentUser uid in createSOS: $uid');

    if (uid == null) {
      print('❌ createSOS stop: uid is null');
      return;
    }

    final profile = await _db.collection('users').doc(uid).get();
    final elderName = (profile.data()?['fullName'] ?? '').toString();

    print('🔥 elder profile exists: ${profile.exists}');
    print('🔥 elder profile data: ${profile.data()}');
    print('🔥 elderName: $elderName');

    await _db.collection('sos_requests').add({
      'elderId': uid,
      'elderName': elderName,
      'lat': point.latitude,
      'lng': point.longitude,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });

    print('🔥 sos_requests document added');

    await LiveLocationService.instance.saveHistoryPoint(
      lat: point.latitude,
      lng: point.longitude,
      elderName: elderName,
      source: 'sos',
    );

    print('🔥 saveHistoryPoint done');

    await TelegramNotificationService.instance.queueForMyCaregivers(
      type: 'sos',
      title: '🚨 SOS',
      body: elderName.isEmpty
          ? 'ผู้สูงอายุต้องการความช่วยเหลือ'
          : '$elderName ต้องการความช่วยเหลือ',
      point: point,
    );

    print('🔥 queueForMyCaregivers finished');
  }
}
