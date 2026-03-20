import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'route_search_types.dart';

class RouteMapPanel extends StatelessWidget {
  final MapController mapController;
  final LatLng center;
  final List<LatLng> routePoints;
  final LatLng? currentLocation;
  final LatLng? elderLiveLocation;
  final RoutePoi? selectedPoi;
  final VoidCallback onClearSelectedPoi;
  final ValueChanged<LatLng>? onMapTap;

  const RouteMapPanel({
    super.key,
    required this.mapController,
    required this.center,
    required this.routePoints,
    required this.currentLocation,
    required this.elderLiveLocation,
    required this.selectedPoi,
    required this.onClearSelectedPoi,
    this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: center,
          initialZoom: 14,
          onTap: (_, point) => onMapTap?.call(point),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.elder_care_app',
          ),
          if (routePoints.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
                  strokeWidth: 6,
                  color: Colors.blue,
                ),
              ],
            ),
          if (currentLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: currentLocation!,
                  width: 18,
                  height: 18,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                      border: Border.all(width: 3, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          if (elderLiveLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: elderLiveLocation!,
                  width: 48,
                  height: 48,
                  child: const Icon(
                    Icons.person_pin_circle,
                    size: 44,
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
          if (selectedPoi != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: selectedPoi!.point,
                  width: 56,
                  height: 56,
                  child: GestureDetector(
                    onTap: onClearSelectedPoi,
                    child: Icon(
                      selectedPoi!.type.icon,
                      size: 48,
                      color: selectedPoi!.type.color,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
