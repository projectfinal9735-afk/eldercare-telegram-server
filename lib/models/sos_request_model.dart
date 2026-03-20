import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class SosRequestModel {
  final String id;
  final String elderId;
  final String elderName;
  final double lat;
  final double lng;
  final DateTime? createdAt;

  const SosRequestModel({
    required this.id,
    required this.elderId,
    required this.elderName,
    required this.lat,
    required this.lng,
    this.createdAt,
  });

  LatLng get point => LatLng(lat, lng);

  factory SosRequestModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? <String, dynamic>{};
    return SosRequestModel(
      id: doc.id,
      elderId: (map['elderId'] ?? '').toString(),
      elderName: (map['elderName'] ?? '').toString(),
      lat: (map['lat'] as num?)?.toDouble() ?? 0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
