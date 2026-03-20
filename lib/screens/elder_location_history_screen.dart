import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ElderLocationHistoryScreen extends StatefulWidget {
  final String elderUid;
  final String elderName;

  const ElderLocationHistoryScreen({
    super.key,
    required this.elderUid,
    required this.elderName,
  });

  @override
  State<ElderLocationHistoryScreen> createState() =>
      _ElderLocationHistoryScreenState();
}

class _ElderLocationHistoryScreenState
    extends State<ElderLocationHistoryScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MapController _mapController = MapController();

  DateTime _selectedDay = DateTime.now();
  bool _loading = true;
  String? _error;
  List<_HistoryPoint> _items = const [];
  _HistoryTimeFilter _timeFilter = _HistoryTimeFilter.all;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked == null) return;

    setState(() => _selectedDay = picked);
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final start = DateTime(
        _selectedDay.year,
        _selectedDay.month,
        _selectedDay.day,
      );
      final end = start.add(const Duration(days: 1));

      final snap = await _db
          .collection('users')
          .doc(widget.elderUid)
          .collection('location_history')
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start),
          )
          .where('timestamp', isLessThan: Timestamp.fromDate(end))
          .orderBy('timestamp')
          .get();

      final items = snap.docs
          .map((doc) {
            final data = doc.data();
            final lat = (data['lat'] as num?)?.toDouble();
            final lng = (data['lng'] as num?)?.toDouble();
            final ts = data['timestamp'];
            if (lat == null || lng == null || ts is! Timestamp) {
              return null;
            }

            return _HistoryPoint(
              lat: lat,
              lng: lng,
              timestamp: ts.toDate(),
              source: (data['source'] ?? '').toString(),
              poiName: (data['poi_name'] ?? '').toString(),
            );
          })
          .whereType<_HistoryPoint>()
          .toList();

      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });

      if (items.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _fitMap(_filteredItems);
        });
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message ?? 'โหลดประวัติไม่สำเร็จ';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'โหลดประวัติไม่สำเร็จ';
      });
    }
  }

  List<_HistoryPoint> get _filteredItems {
    return _items.where((e) => _matchesTimeFilter(e.timestamp)).toList();
  }

  bool _matchesTimeFilter(DateTime time) {
    final hour = time.hour;

    switch (_timeFilter) {
      case _HistoryTimeFilter.all:
        return true;
      case _HistoryTimeFilter.morning:
        return hour >= 5 && hour < 12;
      case _HistoryTimeFilter.afternoon:
        return hour >= 12 && hour < 17;
      case _HistoryTimeFilter.evening:
        return hour >= 17 || hour < 5;
    }
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'sos':
        return 'SOS';
      case 'live_tracking':
        return 'ติดตามสด';
      case 'hospital':
        return 'โรงพยาบาลใกล้ฉัน';
      case 'temple':
        return 'วัดใกล้ฉัน';
      case 'pharmacy':
        return 'ร้านยาใกล้ฉัน';
      case 'restaurant':
        return 'ร้านอาหารใกล้ฉัน';
      case 'cafe':
        return 'ร้านคาเฟ่ใกล้ฉัน';
      case 'manual_input':
        return 'กรอกพิกัดเอง';
      case 'manual_pin':
        return 'หมุดที่ปักเอง';
      default:
        return 'อื่นๆ';
    }
  }

  Color _sourceColor(String source) {
    switch (source) {
      case 'sos':
        return Colors.red;
      case 'live_tracking':
        return Colors.blue;
      case 'hospital':
        return Colors.green;
      case 'temple':
        return Colors.orange;
      case 'pharmacy':
        return Colors.purple;
      case 'restaurant':
        return Colors.orange;
      case 'cafe':
        return Colors.brown;
      case 'manual_input':
        return Colors.teal;
      case 'manual_pin':
        return Colors.purple;
      default:
        return Colors.deepOrange;
    }
  }

  void _fitMap(List<_HistoryPoint> items) {
    if (items.isEmpty) return;

    if (items.length == 1) {
      _mapController.move(items.first.latLng, 16);
      return;
    }

    var minLat = items.first.lat;
    var maxLat = items.first.lat;
    var minLng = items.first.lng;
    var maxLng = items.first.lng;

    for (final item in items.skip(1)) {
      if (item.lat < minLat) minLat = item.lat;
      if (item.lat > maxLat) maxLat = item.lat;
      if (item.lng < minLng) minLng = item.lng;
      if (item.lng > maxLng) maxLng = item.lng;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat, minLng),
          LatLng(maxLat, maxLng),
        ),
        padding: const EdgeInsets.all(36),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  String _formatTime(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;
    final points = filteredItems.map((e) => e.latLng).toList();
    final center =
        points.isNotEmpty ? points.first : const LatLng(13.7563, 100.5018);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 239, 150, 91),
        title: Text('ประวัติหมุด - ${widget.elderName}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'วันที่ ${_formatDate(_selectedDay)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('เลือกวันที่'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final filter in _HistoryTimeFilter.values)
                  ChoiceChip(
                    label: Text(filter.label),
                    selected: _timeFilter == filter,
                    onSelected: (_) {
                      setState(() => _timeFilter = filter);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _fitMap(_filteredItems);
                      });
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(child: Text(_error!))
                          : FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: center,
                                initialZoom: 15,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName:
                                      'com.example.elder_care_app',
                                ),
                                if (points.isNotEmpty)
                                  PolylineLayer(
                                    polylines: [
                                      Polyline(
                                        points: points,
                                        strokeWidth: 4,
                                        color: Colors.blue,
                                      ),
                                    ],
                                  ),
                                MarkerLayer(
                                  markers: [
                                    for (var i = 0; i < filteredItems.length; i++)
                                      Marker(
                                        point: filteredItems[i].latLng,
                                        width: 46,
                                        height: 52,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 10,
                                              backgroundColor: i == 0
                                                  ? Colors.green
                                                  : i == filteredItems.length - 1
                                                      ? Colors.red
                                                      : _sourceColor(
                                                          filteredItems[i].source,
                                                        ),
                                              child: Text(
                                                '${i + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              Icons.location_on,
                                              color: _sourceColor(
                                                filteredItems[i].source,
                                              ),
                                              size: 22,
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                if (!_loading && filteredItems.isEmpty)
                                  const Center(
                                    child: ColoredBox(
                                      color: Colors.white,
                                      child: Padding(
                                        padding: EdgeInsets.all(12),
                                        child: Text(
                                          'ยังไม่มีประวัติหมุดในช่วงเวลาที่เลือก',
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: _loading
                ? const SizedBox.shrink()
                : _items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'ถ้ายังไม่ขึ้นข้อมูล แปลว่ายังไม่มีการบันทึก location_history ของผู้สูงอายุ',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: _sourceColor(item.source)
                                      .withOpacity(0.15),
                                  child: Text('${index + 1}'),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatTime(item.timestamp),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text('lat: ${item.lat.toStringAsFixed(6)}'),
                                      Text('lng: ${item.lng.toStringAsFixed(6)}'),
                                      Text(
                                        'ประเภท: ${_sourceLabel(item.source)}',
                                      ),
                                      if (item.poiName.isNotEmpty)
                                        Text('สถานที่: ${item.poiName}'),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _mapController.move(item.latLng, 17),
                                  icon: const Icon(Icons.my_location),
                                  tooltip: 'ไปยังจุดนี้',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

enum _HistoryTimeFilter {
  all('ทั้งหมด'),
  morning('เช้า'),
  afternoon('บ่าย'),
  evening('เย็น');

  final String label;
  const _HistoryTimeFilter(this.label);
}

class _HistoryPoint {
  final double lat;
  final double lng;
  final DateTime timestamp;
  final String source;
  final String poiName;

  const _HistoryPoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
    required this.source,
    this.poiName = '',
  });

  LatLng get latLng => LatLng(lat, lng);
}
