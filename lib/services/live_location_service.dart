import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'abnormal_alert_service.dart';

class LiveLocationService {
  LiveLocationService._();
  static final LiveLocationService instance = LiveLocationService._();

  final _db = FirebaseFirestore.instance;

  static const Duration _minWriteInterval = Duration(seconds: 30);
  static const double _minDistanceMeters = 25;
  static const Duration _historyMinWriteInterval = Duration(minutes: 5);
  static const double _historyMinDistanceMeters = 50;
  static const Duration _historyPruneInterval = Duration(hours: 12);
  static const Duration _historyRetention = Duration(days: 30);

  Position? _lastWrittenPosition;
  DateTime? _lastWrittenAt;
  Position? _lastHistoryPosition;
  DateTime? _lastHistoryAt;
  DateTime? _lastPrunedAt;
  bool _hasActiveSharingSession = false;
  LatLng? _lastKnownPoint;
  DateTime? _lastSuccessfulSyncAt;
  String? _lastSyncMessage;
  bool _lastSyncHadError = false;

  LatLng? get lastKnownPoint => _lastKnownPoint;
  DateTime? get lastSuccessfulSyncAt => _lastSuccessfulSyncAt;
  String? get lastSyncMessage => _lastSyncMessage;
  bool get lastSyncHadError => _lastSyncHadError;


  Future<LatLng?> restoreLastKnownLocation({String? userId}) async {
    final resolvedUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      return _lastKnownPoint;
    }

    final doc = _db.collection('live_locations').doc(resolvedUserId);

    Map<String, dynamic>? parse(DocumentSnapshot<Map<String, dynamic>> snap) {
      final data = snap.data();
      if (data == null) return null;
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return <String, dynamic>{'lat': lat, 'lng': lng};
    }

    try {
      final server = await doc.get(const GetOptions(source: Source.server));
      final data = parse(server);
      if (data != null) {
        return _applyLastKnownLocation(data['lat'] as double, data['lng'] as double, fromCache: false);
      }
    } catch (_) {}

    try {
      final cached = await doc.get(const GetOptions(source: Source.cache));
      final data = parse(cached);
      if (data != null) {
        return _applyLastKnownLocation(data['lat'] as double, data['lng'] as double, fromCache: true);
      }
    } catch (_) {}

    return _lastKnownPoint;
  }

  LatLng _applyLastKnownLocation(double lat, double lng, {required bool fromCache}) {
    _lastKnownPoint = LatLng(lat, lng);
    _lastSyncHadError = false;
    _lastSyncMessage = fromCache
        ? 'ใช้ตำแหน่งล่าสุดจากแคชบนเครื่อง'
        : 'โหลดตำแหน่งล่าสุดจากเซิร์ฟเวอร์แล้ว';
    return _lastKnownPoint!;
  }

  Future<void> updateMyLocation(
    Position position, {
    String? elderName,
    bool force = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _lastKnownPoint = LatLng(position.latitude, position.longitude);

    if (!force && !_shouldWrite(position)) {
      _lastSyncHadError = false;
      _lastSyncMessage = 'รอซิงก์เมื่อมีการเคลื่อนที่หรือครบเวลา';
      return;
    }

    try {
      await _db.collection('live_locations').doc(user.uid).set({
        'elderId': user.uid,
        'elderName': elderName ?? '',
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        'isSharing': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _lastWrittenPosition = position;
      _lastWrittenAt = DateTime.now();
      _hasActiveSharingSession = true;
      _lastSuccessfulSyncAt = DateTime.now();
      _lastSyncHadError = false;
      _lastSyncMessage = 'ซิงก์ตำแหน่งล่าสุดแล้ว';

      await _saveHistoryIfNeeded(
        userId: user.uid,
        position: position,
        elderName: elderName,
        force: force,
      );

      await AbnormalAlertService.instance.onLocationUpdated(
        lat: position.latitude,
        lng: position.longitude,
        elderName: elderName,
      );
    } catch (_) {
      _lastSyncHadError = true;
      _lastSyncMessage = 'บันทึกตำแหน่งไม่สำเร็จ จะลองใหม่อัตโนมัติเมื่อมีสัญญาณ';
      rethrow;
    }
  }

  bool _shouldWrite(Position position) {
    if (!_hasActiveSharingSession || _lastWrittenPosition == null || _lastWrittenAt == null) {
      return true;
    }

    final elapsed = DateTime.now().difference(_lastWrittenAt!);
    final movedMeters = Geolocator.distanceBetween(
      _lastWrittenPosition!.latitude,
      _lastWrittenPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    final accuracyThreshold = max(position.accuracy, 20.0);
    final movedEnough = movedMeters >= max(_minDistanceMeters, accuracyThreshold);
    final waitedLongEnough = elapsed >= _minWriteInterval;

    return movedEnough || waitedLongEnough;
  }

  bool _shouldWriteHistory(Position position) {
    if (!_hasActiveSharingSession || _lastHistoryPosition == null || _lastHistoryAt == null) {
      return true;
    }

    final elapsed = DateTime.now().difference(_lastHistoryAt!);
    final movedMeters = Geolocator.distanceBetween(
      _lastHistoryPosition!.latitude,
      _lastHistoryPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    final accuracyThreshold = max(position.accuracy, 30.0);
    final movedEnough = movedMeters >= max(_historyMinDistanceMeters, accuracyThreshold);
    final waitedLongEnough = elapsed >= _historyMinWriteInterval;

    return movedEnough || waitedLongEnough;
  }

  Future<void> _saveHistoryIfNeeded({
    required String userId,
    required Position position,
    String? elderName,
    bool force = false,
  }) async {
    if (!force && !_shouldWriteHistory(position)) {
      return;
    }

    await _writeHistoryPoint(
      userId: userId,
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
      elderName: elderName,
      source: 'live_tracking',
    );

    _lastHistoryPosition = position;
    _lastHistoryAt = DateTime.now();
  }

  Future<void> saveHistoryPoint({
    required double lat,
    required double lng,
    double? accuracy,
    String? elderName,
    String source = 'manual',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _lastKnownPoint = LatLng(lat, lng);

    await _writeHistoryPoint(
      userId: user.uid,
      lat: lat,
      lng: lng,
      accuracy: accuracy,
      elderName: elderName,
      source: source,
    );
  }

  Future<void> _writeHistoryPoint({
    required String userId,
    required double lat,
    required double lng,
    double? accuracy,
    String? elderName,
    required String source,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('location_history')
        .add({
      'elderId': userId,
      'elderName': elderName ?? '',
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'source': source,
      'timestamp': FieldValue.serverTimestamp(),
    });

    final now = DateTime.now();
    if (_lastPrunedAt == null || now.difference(_lastPrunedAt!) >= _historyPruneInterval) {
      await _pruneOldHistory(userId);
      _lastPrunedAt = now;
    }
  }

  Future<void> _pruneOldHistory(String userId) async {
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(_historyRetention));
    final oldSnap = await _db
        .collection('users')
        .doc(userId)
        .collection('location_history')
        .where('timestamp', isLessThan: cutoff)
        .limit(100)
        .get();

    if (oldSnap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in oldSnap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> setSharingStopped({
    double? lat,
    double? lng,
    String? elderName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _db.collection('live_locations').doc(user.uid).set({
      'elderId': user.uid,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'isSharing': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (lat != null && lng != null) {
      _lastKnownPoint = LatLng(lat, lng);
    }
    _hasActiveSharingSession = false;
    _lastWrittenAt = null;
    _lastWrittenPosition = null;
    _lastHistoryAt = null;
    _lastHistoryPosition = null;
    _lastSyncHadError = false;
    _lastSyncMessage = 'หยุดแชร์ตำแหน่งสดแล้ว';

    await AbnormalAlertService.instance.onSharingStopped(
      lat: lat,
      lng: lng,
      elderName: elderName,
    );
  }
}
