import 'package:flutter/material.dart';
import 'route_search_types.dart';

class PoiListCard extends StatelessWidget {
  final List<RoutePoi> pois;
  final RoutePoiType? nearPoiType;
  final RoutePoi? selectedPoi;
  final double? Function(RoutePoi poi) distanceForPoi;
  final String Function(double? meters) formatDistance;
  final ValueChanged<RoutePoi> onSelect;

  const PoiListCard({
    super.key,
    required this.pois,
    required this.nearPoiType,
    required this.selectedPoi,
    required this.distanceForPoi,
    required this.formatDistance,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 7,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(nearPoiType?.icon ?? Icons.place),
                  const SizedBox(width: 8),
                  Text(
                    '${nearPoiType?.label ?? "สถานที่"}ใกล้ฉัน (เลือก 1 แห่ง)',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pois.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = pois[i];
                final dist = distanceForPoi(p);
                final selected = selectedPoi?.name == p.name &&
                    selectedPoi?.point == p.point &&
                    selectedPoi?.type == p.type;
                return ListTile(
                  dense: true,
                  title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: dist == null ? null : Text('ระยะประมาณ ${formatDistance(dist)}'),
                  leading: Icon(p.type.icon, color: p.type.color),
                  trailing: selected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                  onTap: () => onSelect(p),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
