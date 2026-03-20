import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class WeatherInfo {
  final double temperatureC;
  final int weatherCode;
  final bool isDay;

  const WeatherInfo({
    required this.temperatureC,
    required this.weatherCode,
    required this.isDay,
  });

  String get label {
    switch (weatherCode) {
      case 0:
        return isDay ? 'ท้องฟ้าแจ่มใส' : 'ฟ้าโปร่ง';
      case 1:
      case 2:
      case 3:
        return 'มีเมฆบางส่วน';
      case 45:
      case 48:
        return 'มีหมอก';
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return 'ฝนปรอย';
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
      case 80:
      case 81:
      case 82:
        return 'ฝนตก';
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return 'หิมะ';
      case 95:
      case 96:
      case 99:
        return 'พายุฝนฟ้าคะนอง';
      default:
        return 'สภาพอากาศล่าสุด';
    }
  }
}

class WeatherService {
  static const _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  static Future<WeatherInfo> getCurrentWeather(LatLng point) async {
    final uri = Uri.parse(
      '$_baseUrl?latitude=${point.latitude}&longitude=${point.longitude}'
      '&current=temperature_2m,weather_code,is_day&forecast_days=1',
    );

    final res = await http.get(uri, headers: {
      'User-Agent': 'elder-care-app/1.0',
    });

    if (res.statusCode != 200) {
      throw Exception('โหลดข้อมูลอากาศไม่สำเร็จ (${res.statusCode})');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final current = data['current'] as Map<String, dynamic>?;
    if (current == null) {
      throw Exception('ไม่พบข้อมูลอากาศปัจจุบัน');
    }

    return WeatherInfo(
      temperatureC: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      weatherCode: (current['weather_code'] as num?)?.toInt() ?? -1,
      isDay: ((current['is_day'] as num?)?.toInt() ?? 1) == 1,
    );
  }
}
