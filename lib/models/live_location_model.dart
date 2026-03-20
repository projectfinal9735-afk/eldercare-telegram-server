import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class LiveLocationModel {
  final String elderId;
  final String elderName;
  final double lat;
  final double lng;
  final bool isSharing;
  final DateTime? updatedAt;

  const LiveLocationModel({
    required this.elderId,
    required this.elderName,
    required this.lat,
    required this.lng,
    required this.isSharing,
    this.updatedAt,
  });

  LatLng get point => LatLng(lat, lng);

  factory LiveLocationModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? <String, dynamic>{};
    return LiveLocationModel(
      elderId: (map['elderId'] ?? doc.id).toString(),
      elderName: (map['elderName'] ?? '').toString(),
      lat: (map['lat'] as num?)?.toDouble() ?? 0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0,
      isSharing: map['isSharing'] == true,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
