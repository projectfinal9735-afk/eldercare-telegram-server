import 'package:flutter/material.dart';

class RouteSummaryCard extends StatelessWidget {
  final bool loadingRoute;
  final String title;
  final String distanceText;
  final String durationText;

  const RouteSummaryCard({
    super.key,
    required this.loadingRoute,
    required this.title,
    required this.distanceText,
    required this.durationText,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(loadingRoute ? Icons.sync : Icons.directions, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$title • $distanceText • $durationText',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
