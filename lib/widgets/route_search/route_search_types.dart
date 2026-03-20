import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class RoutePoi {
  final RoutePoiType type;
  final String name;
  final LatLng point;

  const RoutePoi({
    required this.type,
    required this.name,
    required this.point,
  });
}

enum RoutePoiType {
  manualPin(
    label: 'หมุดที่ปักเอง',
    fallbackName: 'หมุดที่ปักเอง',
    icon: Icons.place,
    color: Colors.purple,
  ),
  hospital(
    label: 'โรงพยาบาล',
    fallbackName: 'โรงพยาบาล',
    icon: Icons.local_hospital,
    color: Colors.red,
  ),
  temple(
    label: 'วัด',
    fallbackName: 'วัด',
    icon: Icons.temple_buddhist,
    color: Colors.deepPurple,
  ),
  pharmacy(
    label: 'ร้านยา',
    fallbackName: 'ร้านยา',
    icon: Icons.local_pharmacy,
    color: Colors.green,
  ),
  restaurant(
    label: 'ร้านอาหาร',
    fallbackName: 'ร้านอาหาร',
    icon: Icons.restaurant,
    color: Colors.orange,
  ),
  cafe(
    label: 'ร้านคาเฟ่',
    fallbackName: 'ร้านคาเฟ่',
    icon: Icons.local_cafe,
    color: Colors.brown,
  );

  final String label;
  final String fallbackName;
  final IconData icon;
  final Color color;

  const RoutePoiType({
    required this.label,
    required this.fallbackName,
    required this.icon,
    required this.color,
  });
}
