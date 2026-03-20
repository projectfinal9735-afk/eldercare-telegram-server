import 'package:flutter/material.dart';

class RouteFabMenu extends StatelessWidget {
  final bool expanded;
  final bool loading;
  final bool showLiveLocationToggle;
  final bool isSharingLiveLocation;
  final VoidCallback onToggle;
  final VoidCallback onHospitals;
  final VoidCallback onTemples;
  final VoidCallback onPharmacies;
  final VoidCallback onRestaurants;
  final VoidCallback onCafes;
  final VoidCallback onMyLocation;
  final VoidCallback onSOS;
  final VoidCallback onLiveLocation;

  const RouteFabMenu({
    super.key,
    required this.expanded,
    required this.loading,
    required this.showLiveLocationToggle,
    required this.isSharingLiveLocation,
    required this.onToggle,
    required this.onHospitals,
    required this.onTemples,
    required this.onPharmacies,
    required this.onRestaurants,
    required this.onCafes,
    required this.onMyLocation,
    required this.onSOS,
    required this.onLiveLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: expanded
              ? Column(
                  key: const ValueKey('expanded'),
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (false) ...[
                      _MiniActionButton(
                        label: isSharingLiveLocation ? 'หยุดแชร์ตำแหน่งสด' : 'แชร์ตำแหน่งสด',
                        icon: isSharingLiveLocation ? Icons.location_disabled : Icons.location_searching,
                        onTap: onLiveLocation,
                      ),
                      const SizedBox(height: 10),
                    ],
                    _MiniActionButton(
                      label: 'โรงพยาบาลใกล้ฉัน',
                      icon: Icons.local_hospital,
                      trailing: loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      onTap: loading ? null : onHospitals,
                    ),
                    const SizedBox(height: 10),
                    _MiniActionButton(
                      label: 'วัดใกล้ฉัน',
                      icon: Icons.temple_buddhist,
                      onTap: loading ? null : onTemples,
                    ),
                    const SizedBox(height: 10),
                    _MiniActionButton(
                      label: 'ร้านยาใกล้ฉัน',
                      icon: Icons.local_pharmacy,
                      onTap: loading ? null : onPharmacies,
                    ),
                    const SizedBox(height: 10),
                    _MiniActionButton(
                      label: 'ร้านอาหารใกล้ฉัน',
                      icon: Icons.restaurant,
                      onTap: loading ? null : onRestaurants,
                    ),
                    const SizedBox(height: 10),
                    _MiniActionButton(
                      label: 'ร้านคาเฟ่ใกล้ฉัน',
                      icon: Icons.local_cafe,
                      onTap: loading ? null : onCafes,
                    ),
                    const SizedBox(height: 10),
                    _MiniActionButton(
                      label: 'ตำแหน่งฉัน',
                      icon: Icons.my_location,
                      onTap: onMyLocation,
                    ),
                    const SizedBox(height: 10),
                    _MiniActionButton(
                      label: 'SOS',
                      icon: Icons.sos,
                      isDanger: true,
                      onTap: onSOS,
                    ),
                    const SizedBox(height: 10),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey('collapsed')),
        ),
        FloatingActionButton.extended(
          heroTag: 'mainFab',
          onPressed: onToggle,
          icon: Icon(expanded ? Icons.close : Icons.menu),
          label: Text(expanded ? 'ปิดเมนู' : 'เมนู'),
        ),
      ],
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDanger;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _MiniActionButton({
    required this.label,
    required this.icon,
    this.isDanger = false,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? Colors.red : null;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
