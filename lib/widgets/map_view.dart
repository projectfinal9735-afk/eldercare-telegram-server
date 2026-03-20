import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapView extends StatelessWidget {
  final LatLng center;
  final LatLng? start;
  final LatLng? end;
  final List<LatLng> routePoints;

  const MapView({
    super.key,
    required this.center,
    this.start,
    this.end,
    required this.routePoints,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.elder_care_app',
        ),

        if (start != null || end != null)
          MarkerLayer(
            markers: [
              if (start != null)
                Marker(
                  point: start!,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.my_location, color: Colors.blue),
                ),
              if (end != null)
                Marker(
                  point: end!,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.flag, color: Colors.red),
                ),
            ],
          ),

        if (routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                color: Colors.blue,
                strokeWidth: 4,
              ),
            ],
          ),
      ],
    );
  }
}
