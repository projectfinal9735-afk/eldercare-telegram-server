import 'package:flutter/material.dart';

import '../services/weather_service.dart';

class WeatherBadge extends StatelessWidget {
  final WeatherInfo weather;
  final bool loading;
  final VoidCallback? onRefresh;

  const WeatherBadge({
    super.key,
    required this.weather,
    this.loading = false,
    this.onRefresh,
  });

  IconData _iconFor(WeatherInfo weather) {
    final code = weather.weatherCode;
    if (code == 0) {
      return weather.isDay ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded;
    }
    if (code >= 1 && code <= 3) return Icons.cloud_queue_rounded;
    if (code == 45 || code == 48) return Icons.cloud;
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return Icons.umbrella_rounded;
    }
    if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) {
      return Icons.ac_unit_rounded;
    }
    if (code >= 95) return Icons.thunderstorm_rounded;
    return Icons.wb_cloudy_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(weather), size: 26, color: Colors.orange.shade700),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${weather.temperatureC.toStringAsFixed(0)}°C',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                Text(
                  weather.label,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
            if (onRefresh != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'รีเฟรชอากาศ',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: loading ? null : onRefresh,
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
