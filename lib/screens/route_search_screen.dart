import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/live_location_model.dart';
import '../models/sos_request_model.dart';
import '../models/user_model.dart';
import '../services/app_error.dart';
import '../services/live_location_service.dart';
import '../services/location_service.dart';
import '../services/poi_service.dart';
import '../services/route_service.dart';
import '../services/sos_service.dart';
import '../services/telegram_notification_service.dart';
import '../services/weather_service.dart';
import '../widgets/app_state_card.dart';
import '../widgets/weather_badge.dart';
import '../widgets/route_search/coordinate_input_card.dart';
import '../widgets/route_search/poi_list_card.dart';
import '../widgets/route_search/route_fab_menu.dart';
import '../widgets/route_search/route_map_panel.dart';
import '../widgets/route_search/route_search_types.dart';
import '../widgets/route_search/route_summary_card.dart';

class RouteSearchScreen extends StatefulWidget {
  final bool showCoordinateInput;

  const RouteSearchScreen({
    super.key,
    this.showCoordinateInput = true,
  });

  @override
  State<RouteSearchScreen> createState() => _RouteSearchScreenState();
}

class _RouteSearchScreenState extends State<RouteSearchScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _latCtl = TextEditingController();
  final TextEditingController _lngCtl = TextEditingController();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _caregiverDocSub;
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _sosSubs = [];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _caregiverLiveDocSub;
  final List<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>> _liveLocationSubs = [];

  String? _latestSosLabel;
  String? _latestLiveLocationLabel;
  String? _inlineMessage;
  bool _inlineIsError = false;
  WeatherInfo? _weatherInfo;
  bool _loadingWeather = false;

  LatLng _center = const LatLng(13.7563, 100.5018);
  LatLng? _currentLocation;
  LatLng? _elderLiveLocation;

  List<RoutePoi> _nearPois = [];
  RoutePoiType? _nearPoiType;
  bool _loadingPois = false;
  bool _loadingRoute = false;
  bool _loadingMyLocation = false;

  RoutePoi? _selectedPoi;
  List<LatLng> _routePoints = [];
  double? _routeDistanceMeters;
  double? _routeDurationSeconds;
  bool _fabExpanded = false;
  bool _sharingLiveLocation = false;
  String? _elderFullName;
  Timer? _inlineMessageTimer;

  @override
  void initState() {
    super.initState();
    _primeMyLocation();
    if (widget.showCoordinateInput) {
      _listenLatestSOS();
      _listenLiveLocations();
    }
  }

  @override
  void dispose() {
    _inlineMessageTimer?.cancel();
    _caregiverDocSub?.cancel();
    for (final sub in _sosSubs) {
      sub.cancel();
    }
    _sosSubs.clear();
    _caregiverLiveDocSub?.cancel();
    for (final sub in _liveLocationSubs) {
      sub.cancel();
    }
    _liveLocationSubs.clear();
    LocationService.instance.stopTracking();
    _latCtl.dispose();
    _lngCtl.dispose();
    super.dispose();
  }

  Future<void> _primeMyLocation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = profile.data();
        if (data != null && mounted) {
          _elderFullName = UserModel.fromMap(data).fullName;
        }
      }
      final p = await LocationService.instance.getCurrentLatLng();
      if (!mounted) return;
      setState(() => _currentLocation = p);
      unawaited(_refreshWeather(p));
    } catch (_) {
      // ปล่อยให้กดตำแหน่งเองภายหลัง
    }
  }

  void _listenLatestSOS() {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    _caregiverDocSub?.cancel();
    for (final sub in _sosSubs) {
      sub.cancel();
    }
    _sosSubs.clear();

    final latestByElder = <String, SosRequestModel>{};
    String? lastShownSosId;

    void refreshLatest() {
      if (!mounted) return;
      if (latestByElder.isEmpty) {
        setState(() => _latestSosLabel = null);
        return;
      }

      final latest = latestByElder.values.reduce((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.isAfter(bTime) ? a : b;
      });

      if (latest.lat == 0 && latest.lng == 0) return;

      final label = latest.elderName.trim().isEmpty
          ? 'SOS จากผู้สูงอายุที่ดูแล'
          : 'SOS จาก ${latest.elderName}';

      _latCtl.text = latest.lat.toStringAsFixed(6);
      _lngCtl.text = latest.lng.toStringAsFixed(6);
      _moveTo(latest.point, zoom: 16.5);
      setState(() => _latestSosLabel = label);

      if (lastShownSosId != latest.id) {
        lastShownSosId = latest.id;
        _showSnack('รับพิกัด $label แล้ว');
      }
    }

    _caregiverDocSub = FirebaseFirestore.instance.collection('users').doc(me.uid).snapshots().listen((userSnap) {
      final data = userSnap.data() ?? <String, dynamic>{};
      final elderIds = UserModel.fromMap(data).elderIds.where((e) => e.isNotEmpty).take(10).toList();

      for (final sub in _sosSubs) {
        sub.cancel();
      }
      _sosSubs.clear();
      latestByElder.clear();

      if (elderIds.isEmpty) {
        if (mounted) setState(() => _latestSosLabel = null);
        return;
      }

      for (final elderId in elderIds) {
        final sub = FirebaseFirestore.instance
            .collection('sos_requests')
            .where('elderId', isEqualTo: elderId)
            .snapshots()
            .listen((snap) {
          if (snap.docs.isEmpty) {
            latestByElder.remove(elderId);
            refreshLatest();
            return;
          }

          final docs = snap.docs.map(SosRequestModel.fromDoc).toList()
            ..sort((a, b) {
              final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bTime.compareTo(aTime);
            });

          latestByElder[elderId] = docs.first;
          refreshLatest();
        }, onError: (error) {
          _showInlineMessage(AppError.message(error), isError: true);
        });
        _sosSubs.add(sub);
      }
    }, onError: (error) {
      _showInlineMessage(AppError.message(error), isError: true);
    });
  }

  void _listenLiveLocations() {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    _caregiverLiveDocSub?.cancel();
    for (final sub in _liveLocationSubs) {
      sub.cancel();
    }
    _liveLocationSubs.clear();

    final latestByElder = <String, LiveLocationModel>{};

    void refreshLatest() {
      if (!mounted) return;
      if (latestByElder.isEmpty) {
        setState(() {
          _elderLiveLocation = null;
          _latestLiveLocationLabel = null;
        });
        return;
      }

      final latest = latestByElder.values.reduce((a, b) {
        final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.isAfter(bTime) ? a : b;
      });

      final label = latest.elderName.trim().isEmpty
          ? 'ตำแหน่งสดล่าสุด'
          : 'ตำแหน่งสด: ${latest.elderName}';

      setState(() {
        _elderLiveLocation = latest.point;
        _latestLiveLocationLabel = label;
      });
    }

    _caregiverLiveDocSub = FirebaseFirestore.instance.collection('users').doc(me.uid).snapshots().listen((userSnap) {
      final data = userSnap.data() ?? <String, dynamic>{};
      final elderIds = UserModel.fromMap(data).elderIds.where((e) => e.isNotEmpty).take(10).toList();

      for (final sub in _liveLocationSubs) {
        sub.cancel();
      }
      _liveLocationSubs.clear();
      latestByElder.clear();

      if (elderIds.isEmpty) {
        if (mounted) {
          setState(() {
            _elderLiveLocation = null;
            _latestLiveLocationLabel = null;
          });
        }
        return;
      }

      for (final elderId in elderIds) {
        final sub = FirebaseFirestore.instance
            .collection('live_locations')
            .doc(elderId)
            .snapshots()
            .listen((doc) {
          if (!doc.exists) {
            latestByElder.remove(elderId);
            refreshLatest();
            return;
          }

          final live = LiveLocationModel.fromDoc(doc);
          if (!live.isSharing || live.lat == 0 || live.lng == 0) {
            latestByElder.remove(elderId);
            refreshLatest();
            return;
          }

          latestByElder[elderId] = live;
          refreshLatest();
        }, onError: (error) {
          _showInlineMessage(AppError.message(error), isError: true);
        });
        _liveLocationSubs.add(sub);
      }
    }, onError: (error) {
      _showInlineMessage(AppError.message(error), isError: true);
    });
  }

  Future<LatLng?> _getMyLocation() async {
    try {
      setState(() => _loadingMyLocation = true);
      final p = await LocationService.instance.getCurrentLatLng();
      if (!mounted) return null;
      setState(() => _currentLocation = p);
      unawaited(_refreshWeather(p));
      return p;
    } catch (e) {
      _showInlineMessage(AppError.message(e), isError: true);
      _showSnack(AppError.message(e));
      return null;
    } finally {
      if (mounted) setState(() => _loadingMyLocation = false);
    }
  }

  Future<void> _goToMyLocation() async {
    final p = await _getMyLocation();
    if (p == null) return;
    _moveTo(p, zoom: 16.5);
  }

  Future<void> _refreshWeather([LatLng? point]) async {
    final target = point ?? _currentLocation;
    if (target == null) return;

    if (mounted) {
      setState(() => _loadingWeather = true);
    }

    try {
      final weather = await WeatherService.getCurrentWeather(target);
      if (!mounted) return;
      setState(() => _weatherInfo = weather);
    } catch (e) {
      _showInlineMessage(AppError.message(e), isError: true);
    } finally {
      if (mounted) {
        setState(() => _loadingWeather = false);
      }
    }
  }

  Future<void> _toggleLiveLocation() async {
    if (widget.showCoordinateInput) {
      _showSnack('การแชร์ตำแหน่งสดเปิดได้จากฝั่งผู้สูงอายุ');
      return;
    }

    if (_sharingLiveLocation) {
      final lastPoint = _currentLocation;
      await LocationService.instance.stopTracking();
      await LiveLocationService.instance.setSharingStopped();
      if (lastPoint != null) {
        await _notifyCaregivers(
          type: 'live_stopped',
          title: '🛑 หยุดแชร์ตำแหน่งสด',
          body: _elderFullName?.trim().isNotEmpty == true
              ? '${_elderFullName!} หยุดแชร์ตำแหน่งสดแล้ว'
              : 'ผู้สูงอายุหยุดแชร์ตำแหน่งสดแล้ว',
          point: lastPoint,
        );
      }
      if (!mounted) return;
      setState(() => _sharingLiveLocation = false);
      _showInlineMessage('หยุดแชร์ตำแหน่งสดแล้ว');
      return;
    }

    try {
      var notifiedStart = false;
      await LocationService.instance.startTracking(onPosition: (position) async {
        await LiveLocationService.instance.updateMyLocation(
          position,
          elderName: _elderFullName,
        );
        if (!notifiedStart) {
          notifiedStart = true;
          await _notifyCaregivers(
            type: 'live_started',
            title: '📍 เริ่มแชร์ตำแหน่งสด',
            body: _elderFullName?.trim().isNotEmpty == true
                ? '${_elderFullName!} เริ่มแชร์ตำแหน่งสดแล้ว'
                : 'ผู้สูงอายุเริ่มแชร์ตำแหน่งสดแล้ว',
            point: LatLng(position.latitude, position.longitude),
          );
        }
        if (mounted) {
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
          });
        }
      });
      if (!mounted) return;
      setState(() => _sharingLiveLocation = true);
      _showInlineMessage('กำลังแชร์ตำแหน่งสดให้ผู้ดูแลเห็น', isError: false);
    } catch (e) {
      _showInlineMessage(AppError.message(e), isError: true);
      _showSnack(AppError.message(e));
    }
  }

  void _moveTo(LatLng p, {double zoom = 15}) {
    _center = p;
    _mapController.move(p, zoom);
    setState(() {});
  }

  Future<void> _loadNearbyPois(RoutePoiType type) async {
    if (_loadingPois) return;

    setState(() {
      _loadingPois = true;
      _fabExpanded = false;
      _nearPois = [];
      _nearPoiType = type;
    });

    final me = await _getMyLocation();
    if (me == null) {
      if (!mounted) return;
      setState(() => _loadingPois = false);
      return;
    }

    _clearRoute(keepSelected: false);

    try {
      const radiusMeters = 10000;
      final query = _buildOverpassQuery(
        type: type,
        radiusMeters: radiusMeters,
        lat: me.latitude,
        lon: me.longitude,
      );

      final pois = await PoiService.search(label: type.label, query: query);
      if (pois.isEmpty) {
        _showSnack('ไม่พบ${type.label}ใกล้เคียง');
        if (!mounted) return;
        setState(() => _nearPois = []);
        return;
      }

      final items = pois
          .map((p) => RoutePoi(type: type, name: p.name, point: p.point))
          .toList();

      items.sort((a, b) {
        final da = _haversineMeters(me, a.point);
        final db = _haversineMeters(me, b.point);
        return da.compareTo(db);
      });

      if (!mounted) return;
      setState(() => _nearPois = items.take(5).toList());
      _showSnack('พบ${type.label}ใกล้คุณ ${_nearPois.length} แห่ง');
    } catch (e) {
      _showInlineMessage(AppError.message(e), isError: true);
      _showSnack(AppError.message(e));
    } finally {
      if (mounted) setState(() => _loadingPois = false);
    }
  }

  String _buildOverpassQuery({
    required RoutePoiType type,
    required int radiusMeters,
    required double lat,
    required double lon,
  }) {
    switch (type) {
      case RoutePoiType.hospital:
        return '''
[out:json][timeout:15];
(
  node["amenity"="hospital"](around:$radiusMeters,$lat,$lon);
  way["amenity"="hospital"](around:$radiusMeters,$lat,$lon);
  relation["amenity"="hospital"](around:$radiusMeters,$lat,$lon);
);
out center tags 60;
''';
      case RoutePoiType.temple:
        return '''
[out:json][timeout:15];
(
  node["amenity"="place_of_worship"]["religion"="buddhist"](around:$radiusMeters,$lat,$lon);
  way["amenity"="place_of_worship"]["religion"="buddhist"](around:$radiusMeters,$lat,$lon);
  relation["amenity"="place_of_worship"]["religion"="buddhist"](around:$radiusMeters,$lat,$lon);
  node["building"="temple"](around:$radiusMeters,$lat,$lon);
  way["building"="temple"](around:$radiusMeters,$lat,$lon);
  relation["building"="temple"](around:$radiusMeters,$lat,$lon);
);
out center tags 80;
''';
      case RoutePoiType.pharmacy:
        return '''
[out:json][timeout:15];
(
  node["amenity"="pharmacy"](around:$radiusMeters,$lat,$lon);
  way["amenity"="pharmacy"](around:$radiusMeters,$lat,$lon);
  relation["amenity"="pharmacy"](around:$radiusMeters,$lat,$lon);
);
out center tags 80;
''';
      case RoutePoiType.restaurant:
        return '''
[out:json][timeout:15];
(
  node["amenity"="restaurant"](around:$radiusMeters,$lat,$lon);
  way["amenity"="restaurant"](around:$radiusMeters,$lat,$lon);
  relation["amenity"="restaurant"](around:$radiusMeters,$lat,$lon);
);
out center tags 80;
''';
      case RoutePoiType.cafe:
        return '''
[out:json][timeout:15];
(
  node["amenity"="cafe"](around:$radiusMeters,$lat,$lon);
  way["amenity"="cafe"](around:$radiusMeters,$lat,$lon);
  relation["amenity"="cafe"](around:$radiusMeters,$lat,$lon);
);
out center tags 80;
''';
      case RoutePoiType.manualPin:
        return '';
    }
  }

  Future<void> _pickPoi(RoutePoi p) async {
    final me = _currentLocation ?? await _getMyLocation();
    if (me == null) return;

    setState(() {
      _selectedPoi = p;
      _nearPois = [];
    });

    _moveTo(p.point, zoom: 15.5);

    try {
      await _saveHistoryPoint(
        point: p.point,
        source: p.type.name,
        poiName: p.name,
      );
      await _notifyCaregivers(
        type: p.type.name,
        title: '🗺 เลือกปลายทาง',
        body: 'กำลังไปที่ ${p.name}',
        point: p.point,
        extra: {'poi_name': p.name, 'poi_type': p.type.name},
      );
    } catch (e) {
      _showInlineMessage(AppError.message(e), isError: true);
    }

    await _fetchRoute(me, p.point);
  }

  Future<void> _notifyCaregivers({
    required String type,
    required String title,
    required String body,
    required LatLng point,
    Map<String, dynamic>? extra,
  }) async {
    try {
      await TelegramNotificationService.instance.queueForMyCaregivers(
        type: type,
        title: title,
        body: body,
        point: point,
        extra: extra,
      );
    } catch (_) {
      // ไม่ให้การส่งเข้าคิวทำให้หน้าแอปล้ม
    }
  }

  Future<void> _fetchRoute(LatLng from, LatLng to) async {
    try {
      setState(() => _loadingRoute = true);
      final result = await RouteService.getRoute(start: from, end: to);
      if (!mounted) return;

      setState(() {
        _routePoints = result.points;
        _routeDistanceMeters = result.distanceMeters;
        _routeDurationSeconds = result.durationSeconds;
      });

      if (result.points.isNotEmpty) {
        _showInlineMessage('ค้นหาเส้นทางสำเร็จ', isError: false);
      } else {
        _showInlineMessage('ไม่พบเส้นทาง', isError: true);
      }
    } catch (e) {
      _showInlineMessage(AppError.message(e), isError: true);
      _showSnack(AppError.message(e));
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  void _clearRoute({required bool keepSelected}) {
    setState(() {
      _routePoints = [];
      _routeDistanceMeters = null;
      _routeDurationSeconds = null;
      if (!keepSelected) _selectedPoi = null;
    });
  }

  LatLng? get _sosPoint => _currentLocation ?? _selectedPoi?.point;

  Future<void> _onSOS() async {
    final p = _sosPoint ?? await _getMyLocation();
    if (p == null) {
      _showSnack('ยังไม่มีพิกัด (กดตำแหน่งฉันก่อน)');
      return;
    }

    try {
      await SosService.instance.createSOS(point: p);
    } catch (e) {
      _showInlineMessage(AppError.message(e), isError: true);
    }

    final text = 'SOS! พิกัด: ${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}';

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('SOS ขอความช่วยเหลือ'),
        content: Text('$text\n\nคัดลอกพิกัดส่งให้ผู้ดูแล หรือโทรฉุกเฉินได้'),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) Navigator.pop(context);
              _showSnack('คัดลอกพิกัดแล้ว');
            },
            child: const Text('คัดลอกพิกัด'),
          ),
          TextButton(
            onPressed: () async {
              final uri = Uri.parse('tel:1669');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                _showSnack('โทรไม่สำเร็จ');
              }
            },
            child: const Text('โทร 1669'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  void _showInlineMessage(String msg, {bool isError = false}) {
    if (!mounted) return;

    _inlineMessageTimer?.cancel();

    setState(() {
      _inlineMessage = msg;
      _inlineIsError = isError;
    });

    _inlineMessageTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _inlineMessage = null;
      });
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _goToCoordinateInput() async {
    final lat = double.tryParse(_latCtl.text.trim());
    final lng = double.tryParse(_lngCtl.text.trim());
    if (lat == null || lng == null) {
      _showSnack('กรุณากรอกพิกัดให้ถูกต้อง');
      return;
    }

    final p = LatLng(lat, lng);
    final start = _currentLocation ?? await _getMyLocation();
    if (start == null) {
      _showSnack('ไม่สามารถหาตำแหน่งเริ่มต้นได้');
      return;
    }

    _moveTo(p, zoom: 16.5);
    setState(() {
      _selectedPoi = RoutePoi(
        name: 'พิกัดที่รับมา',
        point: p,
        type: RoutePoiType.manualPin,
      );
    });

    try {
      await _saveHistoryPoint(
        point: p,
        source: 'manual_input',
        poiName: 'พิกัดที่รับมา',
      );
      await _notifyCaregivers(
        type: 'manual_input',
        title: '📍 กรอกพิกัดเอง',
        body: 'มีการเลือกพิกัดปลายทางเอง',
        point: p,
      );
    } catch (e) {
      _showInlineMessage(AppError.message(e), isError: true);
    }

    await _fetchRoute(start, p);
  }


  Future<void> _saveHistoryPoint({
    required LatLng point,
    required String source,
    String? poiName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('location_history')
        .add({
      'lat': point.latitude,
      'lng': point.longitude,
      'timestamp': FieldValue.serverTimestamp(),
      'source': source,
      if (poiName != null && poiName.trim().isNotEmpty) 'poi_name': poiName.trim(),
    });
  }

  Future<void> _confirmAndPinPoint(LatLng point) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการปักหมุด'),
        content: Text(
          'ต้องการปักหมุดที่\n'
          '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}\n\n'
          'ระบบจะบันทึกลงประวัติด้วย',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final start = _currentLocation ?? await _getMyLocation();
    if (!mounted) return;

    final pinnedPoi = RoutePoi(
      name: RoutePoiType.manualPin.fallbackName,
      point: point,
      type: RoutePoiType.manualPin,
    );

    setState(() {
      _selectedPoi = pinnedPoi;
      _nearPois = [];
      _nearPoiType = null;
    });

    _moveTo(point, zoom: 16.5);

    try {
      await _saveHistoryPoint(
        point: point,
        source: 'manual_pin',
        poiName: pinnedPoi.name,
      );
      await _notifyCaregivers(
        type: 'manual_pin',
        title: '📌 ปักหมุดใหม่',
        body: 'มีการปักหมุดใหม่บนแผนที่',
        point: point,
      );
    } catch (e) {
      _showInlineMessage(AppError.message(e), isError: true);
    }

    if (start != null) {
      await _fetchRoute(start, point);
    } else {
      _showSnack('ปักหมุดและบันทึกประวัติแล้ว');
    }
  }

  double _haversineMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
    return 2 * r * asin(min(1, sqrt(h)));
  }

  double _deg2rad(double d) => d * pi / 180.0;

  double? _distanceForPoi(RoutePoi poi) {
    final me = _currentLocation;
    if (me == null) return null;
    return _haversineMeters(me, poi.point);
  }

  String _formatDistance(double? meters) {
    if (meters == null) return '-';
    if (meters < 1000) return '${meters.toStringAsFixed(0)} ม.';
    return '${(meters / 1000).toStringAsFixed(1)} กม.';
  }

  String _formatDuration(double? seconds) {
    if (seconds == null) return '-';
    final mins = (seconds / 60).round();
    if (mins < 60) return '$mins นาที';
    final h = mins ~/ 60;
    final m = mins % 60;
    return '$h ชม. $m นาที';
  }

  @override
  Widget build(BuildContext context) {
    const mapPadding = EdgeInsets.fromLTRB(16, 170, 16, 30);

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: mapPadding,
            child: RouteMapPanel(
              mapController: _mapController,
              center: _center,
              routePoints: _routePoints,
              currentLocation: _currentLocation,
              elderLiveLocation: _elderLiveLocation,
              selectedPoi: _selectedPoi,
              onClearSelectedPoi: () {
                _clearRoute(keepSelected: false);
                _showSnack('ยกเลิกเส้นทางแล้ว');
              },
              onMapTap: _confirmAndPinPoint,
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 12,
          child: Column(
            children: [
              if (_inlineMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppStateCard(
                    icon: _inlineIsError ? Icons.error_outline : Icons.info_outline,
                    message: _inlineMessage!,
                  ),
                ),
              if (_weatherInfo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: WeatherBadge(
                      weather: _weatherInfo!,
                      loading: _loadingWeather,
                      onRefresh: () => _refreshWeather(),
                    ),
                  ),
                ),
              if (widget.showCoordinateInput)
                CoordinateInputCard(
                  latController: _latCtl,
                  lngController: _lngCtl,
                  latestSosLabel: _latestSosLabel,
                  latestLiveLocationLabel: _latestLiveLocationLabel,
                  onSubmit: _goToCoordinateInput,
                )
              else
                AppStateCard(
                  icon: _sharingLiveLocation ? Icons.my_location : Icons.location_searching,
                  message: _sharingLiveLocation ? 'กำลังแชร์ตำแหน่งสดให้ผู้ดูแล' : 'ยังไม่ได้เปิดแชร์ตำแหน่งสด',
                  actionLabel: _sharingLiveLocation ? 'หยุดแชร์' : 'เริ่มแชร์',
                  onAction: _toggleLiveLocation,
                ),
              if (_nearPois.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: PoiListCard(
                    pois: _nearPois,
                    nearPoiType: _nearPoiType,
                    selectedPoi: _selectedPoi,
                    distanceForPoi: _distanceForPoi,
                    formatDistance: _formatDistance,
                    onSelect: _pickPoi,
                  ),
                ),
            ],
          ),
        ),
        if (_routePoints.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 30,
            child: RouteSummaryCard(
              loadingRoute: _loadingRoute,
              title: _selectedPoi?.name ?? 'ปลายทาง',
              distanceText: _formatDistance(_routeDistanceMeters),
              durationText: _formatDuration(_routeDurationSeconds),
            ),
          ),
        Positioned(
          right: 14,
          bottom: 14,
          child: RouteFabMenu(
            expanded: _fabExpanded,
            loading: _loadingPois || _loadingMyLocation,
            isSharingLiveLocation: _sharingLiveLocation,
            showLiveLocationToggle: !widget.showCoordinateInput,
            onToggle: () => setState(() => _fabExpanded = !_fabExpanded),
            onHospitals: () async {
              if (_loadingPois) return;
              setState(() => _fabExpanded = false);
              await _loadNearbyPois(RoutePoiType.hospital);
            },
            onTemples: () async {
              if (_loadingPois) return;
              setState(() => _fabExpanded = false);
              await _loadNearbyPois(RoutePoiType.temple);
            },
            onPharmacies: () async {
              if (_loadingPois) return;
              setState(() => _fabExpanded = false);
              await _loadNearbyPois(RoutePoiType.pharmacy);
            },
            onRestaurants: () async {
              if (_loadingPois) return;
              setState(() => _fabExpanded = false);
              await _loadNearbyPois(RoutePoiType.restaurant);
            },
            onCafes: () async {
              if (_loadingPois) return;
              setState(() => _fabExpanded = false);
              await _loadNearbyPois(RoutePoiType.cafe);
            },
            onMyLocation: () async {
              setState(() => _fabExpanded = false);
              await _goToMyLocation();
            },
            onSOS: () async {
              setState(() => _fabExpanded = false);
              await _onSOS();
            },
            onLiveLocation: () async {
              setState(() => _fabExpanded = false);
              await _toggleLiveLocation();
            },
          ),
        ),
      ],
    );
  }
}
