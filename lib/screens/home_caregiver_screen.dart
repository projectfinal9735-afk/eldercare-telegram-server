import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'profile_screen.dart';
import 'package:latlong2/latlong.dart';
import 'change_password_screen.dart';
import '../theme/app_colors.dart';
import '../services/weather_service.dart';
import '../services/app_error.dart';
import '../services/location_service.dart';
import 'elder_location_history_screen.dart';
import '../root.dart';
import '../services/telegram_connect_service.dart';
import 'signup_elder_screen.dart';



class HomeCaregiverScreen extends StatefulWidget {
  const HomeCaregiverScreen({super.key});

  @override
  State<HomeCaregiverScreen> createState() => _HomeCaregiverScreenState();
}

class _HomeCaregiverScreenState extends State<HomeCaregiverScreen> {
  int _index = 0;

  String get _title {
    switch (_index) {
      case 0:
        return 'คนใกล้ชิด';
      case 1:
        return 'แดชบอร์ดคนใกล้ชิด';
      case 2:
        return 'ข้อมูลส่วนตัว (คนใกล้ชิด)';
      default:
        return '';
    }
  }


  Future<void> _acceptRequest({required String elderUid}) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    final db = FirebaseFirestore.instance;
    final caregiverUid = me.uid;
    final reqId = '${elderUid}_$caregiverUid';

    try {
      final elderRef = db.collection('users').doc(elderUid);
      final caregiverRef = db.collection('users').doc(caregiverUid);
      final reqRef = db.collection('caregiver_requests').doc(reqId);

      await db.runTransaction((tx) async {
        final elderSnap = await tx.get(elderRef);
        if (!elderSnap.exists) {
          throw Exception('ไม่พบข้อมูลผู้สูงอายุ');
        }

        final elderData = elderSnap.data() ?? <String, dynamic>{};
        final caregiverIds = (elderData['caregiverIds'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();

        final alreadyLinkedToThisCaregiver = caregiverIds.contains(caregiverUid);
        final hasAnotherCaregiver = caregiverIds.isNotEmpty && !alreadyLinkedToThisCaregiver;

        if (hasAnotherCaregiver) {
          throw Exception('ผู้สูงอายุมีคนใกล้ชิดอยู่แล้ว กรุณาลบคนใกล้ชิดเดิมก่อน');
        }

        tx.set(reqRef, {
          'elderId': elderUid,
          'caregiverId': caregiverUid,
          'status': 'accepted',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        tx.update(elderRef, {
          'caregiverIds': [caregiverUid],
          'updatedAt': FieldValue.serverTimestamp(),
        });

        tx.set(caregiverRef, {
          'elderIds': FieldValue.arrayUnion([elderUid]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยอมรับคำขอแล้ว')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'ยอมรับไม่สำเร็จ')),
      );
    } on Exception catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.isEmpty ? 'ยอมรับไม่สำเร็จ' : message)),
      );
    }
  }

  Future<void> _rejectRequest({required String elderUid}) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    final caregiverUid = me.uid;
    try {
      await FirebaseFirestore.instance
          .collection('caregiver_requests')
          .doc('${elderUid}_$caregiverUid')
          .set({
        'elderId': elderUid,
        'caregiverId': caregiverUid,
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ปฏิเสธคำขอแล้ว')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'ปฏิเสธไม่สำเร็จ')),
      );
    }
  }

  void _showPendingRequestsSheet(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      builder: (sheetContext) {
        final q = FirebaseFirestore.instance
            .collection('caregiver_requests')
            .where('caregiverId', isEqualTo: me.uid);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                  return const SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snap.hasError) {
                  return SizedBox(
                    height: 240,
                    child: Center(
                      child: Text(
                        'โหลดการแจ้งเตือนไม่สำเร็จ\n${snap.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.deepOrange),
                      ),
                    ),
                  );
                }

                final docs = (snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    .where((d) => (d.data()['status'] ?? '').toString() == 'pending')
                    .toList();

                if (docs.isEmpty) {
                  return const SizedBox(
                    height: 240,
                    child: Center(
                      child: Text(
                        'ยังไม่มีคำขอใหม่',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                      ),
                    ),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'การแจ้งเตือน',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'คำขอเป็นคนใกล้ชิดที่รอการตอบรับ ${docs.length} รายการ',
                      style: const TextStyle(color: AppColors.subtleText),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final d = docs[index];
                          final data = d.data();
                          String elderUid = (data['elderId'] ?? data['elderUid'] ?? '').toString().trim();

                          if (elderUid.isEmpty) {
                            final parts = d.id.split('_');
                            if (parts.length >= 2) {
                              elderUid = parts.first;
                            }
                          }

                          if (elderUid.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Text(
                                'พบคำขอ แต่ข้อมูลผู้ส่งไม่ครบ',
                                style: TextStyle(color: Colors.deepOrange),
                              ),
                            );
                          }

                          return _NotificationRequestTile(
                            elderUid: elderUid,
                            onAccept: () async {
                              await _acceptRequest(elderUid: elderUid);
                              if (!sheetContext.mounted) return;
                              Navigator.of(sheetContext).maybePop();
                            },
                            onReject: () async {
                              await _rejectRequest(elderUid: elderUid);
                              if (!sheetContext.mounted) return;
                              Navigator.of(sheetContext).maybePop();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const CaregiverEldersScreen(showDashboard: false),
      const CaregiverDashboardScreen(),
      CaregiverProfileTab(onChangePassword: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
        );
      }),
    ];

    return Scaffold(
      appBar: AppBar(
  backgroundColor: AppColors.primary, // ✅ ฟ้าเดียวกับแถบล่าง
  elevation: 0,
  title: Text(
    _title,
    style: const TextStyle(
      color: AppColors.card, // ✅ ตัวหนังสือขาว
      fontWeight: FontWeight.w600,
    ),
  ),
  iconTheme: const IconThemeData(
    color: AppColors.card, // ✅ ไอคอนฝั่งซ้าย
  ),
  actionsIconTheme: const IconThemeData(
    color: AppColors.card, // ✅ ไอคอนฝั่งขวา
  ),
  actions: [
    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseAuth.instance.currentUser == null
          ? null
          : FirebaseFirestore.instance
              .collection('caregiver_requests')
              .where('caregiverId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
              .snapshots(),
      builder: (context, snap) {
        final pendingCount = (snap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            .where((d) => (d.data()['status'] ?? '').toString() == 'pending')
            .length;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'การแจ้งเตือน',
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () => _showPendingRequestsSheet(context),
            ),
            if (pendingCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.card, width: 1.4),
                  ),
                  child: Text(
                    pendingCount > 99 ? '99+' : '$pendingCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.card,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
    IconButton(
      icon: const Icon(Icons.logout),
      onPressed: () async {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Root()),
          (_) => false,
        );
      },
    ),
  ],
),




      // ✅ เปลี่ยนหน้าทันที ไม่ push
      body: IndexedStack(
        index: _index,
        children: pages,
      ),

      bottomNavigationBar: _BottomActionBar(
        currentIndex: _index,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const _BottomActionBar({
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.card;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            _NavActionItem(
              icon: Icons.groups_rounded,
              label: 'คนใกล้ชิด',
              selected: currentIndex == 0,
              color: color,
              onTap: () => onSelect(0),
            ),
            _NavActionItem(
              icon: Icons.dashboard_rounded,
              label: 'แดชบอร์ด',
              selected: currentIndex == 1,
              color: color,
              onTap: () => onSelect(1),
            ),
            _NavActionItem(
              icon: Icons.person,
              label: 'โปรไฟล์',
              selected: currentIndex == 2,
              color: color,
              onTap: () => onSelect(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavActionItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _NavActionItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  State<_NavActionItem> createState() => _NavActionItemState();
}

class _NavActionItemState extends State<_NavActionItem> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final opacity = selected ? 1.0 : 0.72;

    return Expanded(
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          borderRadius: BorderRadius.circular(14),
          splashColor: AppColors.card.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: selected ? AppColors.card.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: selected ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      widget.icon,
                      size: 34,
                      color: widget.color.withValues(alpha: opacity),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      color: widget.color.withValues(alpha: opacity),
                    ),
                    child: Text(widget.label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// placeholder: รายชื่อผู้สูงอายุที่คนใกล้ชิดดูแลอยู่
class CaregiverEldersScreen extends StatefulWidget {
  const CaregiverEldersScreen({
    super.key,
    this.showDashboard = true,
  });

  final bool showDashboard;

  @override
  State<CaregiverEldersScreen> createState() => _CaregiverEldersScreenState();
}

class _CaregiverEldersScreenState extends State<CaregiverEldersScreen> {
  User? get _me => FirebaseAuth.instance.currentUser;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  int _refreshVersion = 0;
  bool _isRefreshing = false;
  Map<String, dynamic>? _cachedCaregiverData;
  List<String> _cachedElderIds = const <String>[];
  String? _caregiverFallbackNote;
  bool _usingCachedCaregiverData = false;

  @override
  void initState() {
    super.initState();
    _primeCachedCaregiverData();
  }

  List<String> _extractElderIds(Map<String, dynamic> data) {
    return (data['elderIds'] as List?)?.cast<String>() ?? const <String>[];
  }

  void _storeCaregiverCache(
    Map<String, dynamic> data, {
    bool usingCache = false,
    String? note,
  }) {
    _cachedCaregiverData = Map<String, dynamic>.from(data);
    _cachedElderIds = _extractElderIds(data);
    _usingCachedCaregiverData = usingCache;
    _caregiverFallbackNote = note;
  }

  Future<void> _primeCachedCaregiverData() async {
    final me = _me;
    if (me == null) return;
    try {
      final cached = await _db.collection('users').doc(me.uid).get(const GetOptions(source: Source.cache));
      final data = cached.data();
      if (data == null || !mounted) return;
      setState(() {
        _storeCaregiverCache(
          data,
          usingCache: true,
          note: _extractElderIds(data).isEmpty ? null : 'กำลังแสดงรายชื่อผู้สูงอายุจากข้อมูลล่าสุดที่เก็บไว้บนเครื่อง',
        );
      });
    } catch (_) {}
  }

  Future<void> _refreshCaregiverData({bool showMessage = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final me = _me;
      if (me != null) {
        final results = await Future.wait([
          _db.collection('users').doc(me.uid).get(const GetOptions(source: Source.server)),
          _db
              .collection('caregiver_requests')
              .where('caregiverId', isEqualTo: me.uid)
              .where('status', isEqualTo: 'pending')
              .get(const GetOptions(source: Source.server)),
        ]);
        final caregiverSnap = results.first as DocumentSnapshot<Map<String, dynamic>>;
        final data = caregiverSnap.data();
        if (data != null && mounted) {
          setState(() {
            _storeCaregiverCache(data, usingCache: false, note: null);
          });
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      setState(() => _refreshVersion++);
      if (showMessage) {
        _snack('รีเฟรชข้อมูลล่าสุดแล้ว');
      }
    } catch (e) {
      if (!mounted) return;
      if (_cachedCaregiverData != null) {
        setState(() {
          _usingCachedCaregiverData = true;
          _caregiverFallbackNote = 'รีเฟรชไม่สำเร็จ กำลังใช้รายชื่อผู้สูงอายุจากแคชบนเครื่อง';
        });
        if (showMessage) {
          _snack(_caregiverFallbackNote!);
        }
      } else {
        _snack(AppError.message(e));
      }
    } finally {
      _isRefreshing = false;
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
  Future<void> caregiverRemoveElder(String elderUid) async {
    final me = _me;
    if (me == null) return;

    final caregiverUid = me.uid;
    final elderRef = _db.collection('users').doc(elderUid);
    final caregiverRef = _db.collection('users').doc(caregiverUid);
    final reqRef = _db.collection('caregiver_requests').doc('${elderUid}_$caregiverUid');

    try {
      await _db.runTransaction((tx) async {
        tx.set(
          caregiverRef,
          {
            'elderIds': FieldValue.arrayRemove([elderUid]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        tx.set(
          elderRef,
          {
            'caregiverIds': FieldValue.arrayRemove([caregiverUid]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        tx.set(
          reqRef,
          {
            'elderId': elderUid,
            'caregiverId': caregiverUid,
            'status': 'canceled',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      _snack('ออกจากการดูแลแล้ว');
    } on FirebaseException catch (e) {
      _snack(e.message ?? 'ทำรายการไม่สำเร็จ');
    }
  }


  Future<void> _acceptRequest({required String elderUid}) async {
  final me = _me;
  if (me == null) return;

  final caregiverUid = me.uid;
  final reqId = '${elderUid}_$caregiverUid';

  try {
    final elderRef = _db.collection('users').doc(elderUid);
    final caregiverRef = _db.collection('users').doc(caregiverUid);
    final reqRef = _db.collection('caregiver_requests').doc(reqId);

    await _db.runTransaction((tx) async {
      final elderSnap = await tx.get(elderRef);
      if (!elderSnap.exists) {
        throw Exception('ไม่พบข้อมูลผู้สูงอายุ');
      }

      final elderData = elderSnap.data() ?? <String, dynamic>{};
      final caregiverIds = (elderData['caregiverIds'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();

      final alreadyLinkedToThisCaregiver = caregiverIds.contains(caregiverUid);
      final hasAnotherCaregiver = caregiverIds.isNotEmpty && !alreadyLinkedToThisCaregiver;

      if (hasAnotherCaregiver) {
        throw Exception('ผู้สูงอายุมีคนใกล้ชิดอยู่แล้ว กรุณาลบคนใกล้ชิดเดิมก่อน');
      }

      tx.set(reqRef, {
        'elderId': elderUid,
        'caregiverId': caregiverUid,
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.update(elderRef, {
        'caregiverIds': [caregiverUid],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.set(caregiverRef, {
        'elderIds': FieldValue.arrayUnion([elderUid]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    _snack('ยอมรับคำขอแล้ว');
} on FirebaseException catch (e) {
  _snack(e.message ?? 'ยอมรับไม่สำเร็จ');
} on Exception catch (e) {
  final message = e.toString().replaceFirst('Exception: ', '');
  _snack(message.isEmpty ? 'ยอมรับไม่สำเร็จ' : message);
}
}


  Future<void> _rejectRequest({required String elderUid}) async {
    final me = _me;
    if (me == null) return;
    final caregiverUid = me.uid;
    final reqId = '${elderUid}_$caregiverUid';
    try {
      await _db.collection('caregiver_requests').doc(reqId).set({
        'elderId': elderUid,
        'caregiverId': caregiverUid,
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _snack('ปฏิเสธคำขอแล้ว');
    } on FirebaseException catch (e) {
      _snack(e.message ?? 'ปฏิเสธไม่สำเร็จ');
    }
  }

  Widget _pendingRequests() {
    final me = _me;
    if (me == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Text('กรุณาเข้าสู่ระบบก่อน'),
      );
    }

    final q = _db
        .collection('caregiver_requests')
        .where('caregiverId', isEqualTo: me.uid)
        .where('status', isEqualTo: 'pending');

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'คำขอเป็นคนใกล้ชิด (รอการตอบรับ)',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final elderUid = (data['elderId'] ?? '').toString();
              return _ElderRequestTile(
                key: ValueKey('request-$elderUid-$_refreshVersion'),
                elderUid: elderUid,
                onAccept: () => _acceptRequest(elderUid: elderUid),
                onReject: () => _rejectRequest(elderUid: elderUid),
              );
            }),
            const SizedBox(height: 18),
          ],
        );
      },
    );
  }

  Widget _acceptedElders() {
    final me = _me;
    if (me == null) {
      return const Center(child: Text('กรุณาเข้าสู่ระบบก่อน'));
    }

    final caregiverDoc = _db.collection('users').doc(me.uid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: caregiverDoc.snapshots(includeMetadataChanges: true),
      builder: (context, snap) {
        if (snap.hasData) {
          final freshData = snap.data?.data();
          if (freshData != null) {
            final fromCache = snap.data?.metadata.isFromCache ?? false;
            _storeCaregiverCache(
              freshData,
              usingCache: fromCache,
              note: fromCache && _extractElderIds(freshData).isNotEmpty
                  ? 'กำลังแสดงรายชื่อผู้สูงอายุจากแคชบนเครื่อง'
                  : null,
            );
          }
        }

        if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
          if (_cachedCaregiverData != null) {
            return _buildAcceptedEldersContent(
              _cachedElderIds,
              helperNote: _caregiverFallbackNote ?? 'กำลังแสดงข้อมูลที่บันทึกไว้ล่าสุดระหว่างรอเชื่อมต่อ',
            );
          }
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError && _cachedCaregiverData != null) {
          return _buildAcceptedEldersContent(
            _cachedElderIds,
            helperNote: 'โหลดรายชื่อจากเซิร์ฟเวอร์ไม่สำเร็จ กำลังใช้ข้อมูลล่าสุดที่เก็บไว้บนเครื่อง',
          );
        }

        final ids = snap.data?.data() != null ? _extractElderIds(snap.data!.data()!) : _cachedElderIds;
        return _buildAcceptedEldersContent(
          ids,
          helperNote: _usingCachedCaregiverData ? _caregiverFallbackNote : null,
        );
      },
    );
  }

  Widget _buildAcceptedEldersContent(
    List<String> ids, {
    String? helperNote,
  }) {
    if (ids.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            const Text(
              'ยังไม่มีผู้สูงอายุที่คุณดูแล\nเมื่อ Elder ส่งคำขอมา คุณสามารถกดยอมรับได้ที่ด้านบน',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.subtleText),
            ),
            if (helperNote != null) ...[
              const SizedBox(height: 10),
              Text(
                helperNote,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.subtleText),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (helperNote != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              helperNote,
              style: const TextStyle(color: AppColors.subtleText),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.showDashboard) ...[
          _CaregiverDashboardSection(elderIds: ids),
          const SizedBox(height: 18),
        ],
        const Text(
          'ผู้สูงอายุที่คุณดูแล',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...ids.map((eid) => _ElderTile(
              key: ValueKey('elder-$eid-$_refreshVersion'),
              elderUid: eid,
              onRemove: () => caregiverRemoveElder(eid),
            )),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => _refreshCaregiverData(showMessage: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignupElderScreen(managedByCaregiver: true),
                        ),
                      );
                      if (!mounted) return;
                      await _refreshCaregiverData(showMessage: true);
                    },
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('เพิ่มผู้สูงอายุ'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: () => _refreshCaregiverData(showMessage: true),
                  tooltip: 'รีเฟรชข้อมูล',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'ดึงหน้าจอลงหรือกดปุ่มรีเฟรช หากข้อมูลยังไม่ตรงกับปัจจุบัน',
              style: TextStyle(fontSize: 14, color: AppColors.subtleText),
            ),
            const SizedBox(height: 16),
            _acceptedElders(),
            const SizedBox(height: 24),
            const Text(
              'หมายเหตุ: Elder ต้องส่งคำขอ และคุณต้องกด “ยอมรับ” ก่อนถึงจะเชื่อมกัน',
              style: TextStyle(fontSize: 14, color: AppColors.subtleText),
            ),
          ],
        ),
      ),
    );
  }
}


class CaregiverDashboardScreen extends StatelessWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return const SafeArea(
        child: Center(
          child: Text('กรุณาเข้าสู่ระบบก่อน'),
        ),
      );
    }

    return SafeArea(
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(me.uid).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data?.data() ?? <String, dynamic>{};
          final ids = (data['elderIds'] as List?)?.cast<String>() ?? const <String>[];

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _CaregiverDashboardSection(elderIds: ids),
            ],
          );
        },
      ),
    );
  }
}

class _CaregiverDashboardSection extends StatefulWidget {
  const _CaregiverDashboardSection({required this.elderIds});

  final List<String> elderIds;

  @override
  State<_CaregiverDashboardSection> createState() => _CaregiverDashboardSectionState();
}

class _CaregiverDashboardSectionState extends State<_CaregiverDashboardSection> {
  String? _selectedElderId;

  @override
  void initState() {
    super.initState();
    _selectedElderId = widget.elderIds.isNotEmpty ? widget.elderIds.first : null;
  }

  @override
  void didUpdateWidget(covariant _CaregiverDashboardSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.elderIds.isEmpty) {
      _selectedElderId = null;
      return;
    }
    if (_selectedElderId == null || !widget.elderIds.contains(_selectedElderId)) {
      _selectedElderId = widget.elderIds.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.elderIds.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'แดชบอร์ดสรุป',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(
              'ยังไม่มีผู้สูงอายุที่เชื่อมกับบัญชีนี้\nเพิ่มผู้สูงอายุหรือรอยอมรับคำขอด้านล่างก่อน',
              style: TextStyle(color: AppColors.subtleText),
            ),
          ],
        ),
      );
    }

    final selectedId = _selectedElderId ?? widget.elderIds.first;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'แดชบอร์ดสรุป',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'เปิดมาแล้วเห็นสถานะสำคัญของผู้สูงอายุได้ทันที',
            style: TextStyle(color: AppColors.subtleText),
          ),
          const SizedBox(height: 14),
          if (widget.elderIds.length > 1)
            DropdownButtonFormField<String>(
              value: selectedId,
              decoration: const InputDecoration(
                labelText: 'เลือกผู้สูงอายุ',
                prefixIcon: Icon(Icons.person_search),
              ),
              items: widget.elderIds
                  .map(
                    (id) => DropdownMenuItem<String>(
                      value: id,
                      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: FirebaseFirestore.instance.collection('users').doc(id).get(),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const Text('กำลังโหลด...');
                          }

                          final data = snap.data!.data() ?? <String, dynamic>{};
                          final fullName = (data['fullName'] ?? '').toString().trim();
                          final identifier = (data['identifier'] ?? id).toString();
                          final displayName = fullName.isNotEmpty ? fullName : identifier;

                          return Text(
                            displayName,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedElderId = value);
              },
            ),
          if (widget.elderIds.length > 1) const SizedBox(height: 14),
          _CaregiverDashboardBody(elderUid: selectedId),
        ],
      ),
    );
  }
}


class _DashboardSummaryData {
  final String elderUid;
  final String elderName;
  final String phone;
  final bool isOnline;
  final DateTime? lastLocationAt;
  final int todaySosCount;
  final String weatherLabel;
  final String riskLabel;
  final Color riskColor;
  final double? temperatureC;
  final bool hasLocation;
  final bool geofenceAlert;
  final double? lastLatitude;
  final double? lastLongitude;

  const _DashboardSummaryData({
    required this.elderUid,
    required this.elderName,
    required this.phone,
    required this.isOnline,
    required this.lastLocationAt,
    required this.todaySosCount,
    required this.weatherLabel,
    required this.riskLabel,
    required this.riskColor,
    required this.temperatureC,
    required this.hasLocation,
    required this.geofenceAlert,
    required this.lastLatitude,
    required this.lastLongitude,
  });
}

class _CaregiverDashboardBody extends StatelessWidget {
  const _CaregiverDashboardBody({required this.elderUid});

  final String elderUid;

  String _relativeTime(DateTime? time) {
    if (time == null) return 'ยังไม่มีข้อมูล';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
    if (diff.inDays == 1) return 'เมื่อวาน';
    return '${diff.inDays} วันที่แล้ว';
  }

  String _clockTime(DateTime? time) {
    if (time == null) return '--:--';
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _callEmergency(BuildContext context, String phone) async {
    final cleanedPhone = phone.trim();
    if (cleanedPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยังไม่มีเบอร์โทรสำหรับติดต่อฉุกเฉิน')),
      );
      return;
    }

    try {
      await launchUrl(
        Uri.parse('tel:$cleanedPhone'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเปิดหน้าจอโทรศัพท์ได้')),
      );
    }
  }



  Future<void> _openLatestLocation(BuildContext context, _DashboardSummaryData data) async {
    if (!data.hasLocation || data.lastLatitude == null || data.lastLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยังไม่พบตำแหน่งล่าสุด')),
      );
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${data.lastLatitude},${data.lastLongitude}',
    );

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเปิด Google Maps ได้')),
      );
    }
  }

  Future<_DashboardSummaryData> _load() async {
    final db = FirebaseFirestore.instance;
    final userDoc = await db.collection('users').doc(elderUid).get();
    final userData = userDoc.data() ?? <String, dynamic>{};
    final elderName = ((userData['fullName'] ?? '').toString().trim().isNotEmpty
            ? userData['fullName']
            : userData['identifier'] ?? elderUid)
        .toString();
    final phone = (userData['phone'] ?? '').toString();

    final liveDoc = await db.collection('live_locations').doc(elderUid).get();
    final liveData = liveDoc.data() ?? <String, dynamic>{};

    double? lat = (liveData['lat'] as num?)?.toDouble();
    double? lng = (liveData['lng'] as num?)?.toDouble();
    DateTime? lastLocationAt;
    final updatedAt = liveData['updatedAt'] ?? liveData['timestamp'];
    if (updatedAt is Timestamp) {
      lastLocationAt = updatedAt.toDate();
    }

    if (lat == null || lng == null || lastLocationAt == null) {
      try {
        final historySnap = await db
            .collection('users')
            .doc(elderUid)
            .collection('location_history')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (historySnap.docs.isNotEmpty) {
          final history = historySnap.docs.first.data();
          lat ??= (history['lat'] as num?)?.toDouble();
          lng ??= (history['lng'] as num?)?.toDouble();
          final ts = history['timestamp'];
          if (lastLocationAt == null && ts is Timestamp) {
            lastLocationAt = ts.toDate();
          }
        }
      } catch (_) {}
    }

    final hasLocation = lat != null && lng != null;
    final isSharing = (liveData['isSharing'] ?? false) == true;
    final isOnline = isSharing &&
        lastLocationAt != null &&
        DateTime.now().difference(lastLocationAt).inMinutes <= 10;

    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);

    int sosCount = 0;
    try {
      final sosSnap = await db
          .collection('sos_requests')
          .where('elderId', isEqualTo: elderUid)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .get();
      sosCount = sosSnap.docs.length;
    } catch (_) {
      final sosSnap = await db.collection('sos_requests').where('elderId', isEqualTo: elderUid).get();
      sosCount = sosSnap.docs.where((doc) {
        final createdAt = doc.data()['createdAt'];
        if (createdAt is! Timestamp) return false;
        return !createdAt.toDate().isBefore(dayStart);
      }).length;
    }

    String weatherLabel = 'ยังไม่มีข้อมูลอากาศ';
    double? temperatureC;
    if (hasLocation) {
      try {
        final weather = await WeatherService.getCurrentWeather(LatLng(lat!, lng!));
        weatherLabel = weather.label;
        temperatureC = weather.temperatureC;
      } catch (_) {}
    }

    bool geofenceAlert = false;
    try {
      final geofenceDoc = await db
          .collection('users')
          .doc(elderUid)
          .collection('settings')
          .doc('geofence')
          .get();
      final g = geofenceDoc.data();
      if (g != null &&
          (g['enabled'] ?? false) == true &&
          hasLocation &&
          g['centerLat'] != null &&
          g['centerLng'] != null &&
          g['radiusMeters'] != null) {
        final centerLat = (g['centerLat'] as num).toDouble();
        final centerLng = (g['centerLng'] as num).toDouble();
        final radiusMeters = (g['radiusMeters'] as num).toDouble();
        final distance = _distanceMeters(
          lat1: lat!,
          lng1: lng!,
          lat2: centerLat,
          lng2: centerLng,
        );
        geofenceAlert = distance > radiusMeters;
      }
    } catch (_) {}

    var riskLabel = 'ปกติ';
    Color riskColor = Colors.green;
    if (!hasLocation) {
      riskLabel = 'ยังไม่พบตำแหน่ง';
      riskColor = Colors.grey;
    } else if (sosCount > 0) {
      riskLabel = 'มี SOS วันนี้';
      riskColor = AppColors.danger;
    } else if (geofenceAlert) {
      riskLabel = 'อยู่นอกพื้นที่ปลอดภัย';
      riskColor = Colors.orange;
    } else if (!isOnline) {
      riskLabel = 'ออฟไลน์หรือตำแหน่งไม่ล่าสุด';
      riskColor = Colors.amber.shade800;
    } else if ((temperatureC ?? 0) >= 35) {
      riskLabel = 'อากาศร้อน ควรเฝ้าระวัง';
      riskColor = Colors.deepOrange;
    } else if (weatherLabel.contains('พายุ') || weatherLabel.contains('ฝน')) {
      riskLabel = 'สภาพอากาศควรระวัง';
      riskColor = Colors.blue;
    }

    return _DashboardSummaryData(
      elderUid: elderUid,
      elderName: elderName,
      phone: phone,
      isOnline: isOnline,
      lastLocationAt: lastLocationAt,
      todaySosCount: sosCount,
      weatherLabel: weatherLabel,
      riskLabel: riskLabel,
      riskColor: riskColor,
      temperatureC: temperatureC,
      hasLocation: hasLocation,
      geofenceAlert: geofenceAlert,
      lastLatitude: lat,
      lastLongitude: lng,
    );
  }

  double _distanceMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * 3.141592653589793 / 180.0;
    final dLng = (lng2 - lng1) * 3.141592653589793 / 180.0;
    final a =
        (0.5 - (cos(dLat) / 2)) +
        cos(lat1 * 3.141592653589793 / 180.0) *
            cos(lat2 * 3.141592653589793 / 180.0) *
            (0.5 - (cos(dLng) / 2));
    return earthRadius * 2 * asin(sqrt(a));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream<int>.periodic(const Duration(minutes: 1), (count) => count),
      initialData: 0,
      builder: (context, _) {
        return FutureBuilder<_DashboardSummaryData>(
          future: _load(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError || !snap.hasData) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('โหลดข้อมูลแดชบอร์ดไม่สำเร็จ'),
              );
            }

            final data = snap.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.elderName,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                if (data.phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'โทร: ${data.phone}',
                    style: const TextStyle(color: AppColors.subtleText),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryMetricCard(
                        label: 'สถานะ',
                        value: data.isOnline ? 'ออนไลน์' : 'ออฟไลน์',
                        icon: data.isOnline ? Icons.wifi_tethering : Icons.portable_wifi_off,
                        valueColor: data.isOnline ? Colors.green : AppColors.danger,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryMetricCard(
                        label: 'อัปเดตตำแหน่ง',
                        value: data.lastLocationAt == null
                            ? 'ยังไม่มีข้อมูล'
                            : '${_clockTime(data.lastLocationAt)}\n${_relativeTime(data.lastLocationAt)}',
                        icon: Icons.location_on,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryMetricCard(
                        label: 'SOS วันนี้',
                        value: data.todaySosCount > 0 ? '${data.todaySosCount} ครั้ง' : 'ไม่มี',
                        icon: Icons.warning_amber_rounded,
                        valueColor: data.todaySosCount > 0 ? AppColors.danger : Colors.green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryMetricCard(
                        label: 'สภาพอากาศ',
                        value: data.temperatureC == null
                            ? data.weatherLabel
                            : '${data.weatherLabel}\n${data.temperatureC!.toStringAsFixed(0)}°C',
                        icon: Icons.cloud_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: data.riskColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: data.riskColor.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.health_and_safety_outlined, color: data.riskColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ความเสี่ยงตอนนี้: ${data.riskLabel}',
                          style: TextStyle(
                            color: data.riskColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _callEmergency(context, data.phone),
                        icon: const Icon(Icons.call),
                        label: const Text('ติดต่อฉุกเฉิน'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: AppColors.card,
                          minimumSize: const Size(double.infinity, 56),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openLatestLocation(context, data),
                        icon: const Icon(Icons.location_on_outlined),
                        label: const Text('ดูตำแหน่ง'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          minimumSize: const Size(double.infinity, 56),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _RealtimeDistanceCard(
                  elderUid: data.elderUid,
                  elderName: data.elderName,
                  fallbackLatitude: data.lastLatitude,
                  fallbackLongitude: data.lastLongitude,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _RealtimeDistanceCard extends StatelessWidget {
  const _RealtimeDistanceCard({
    required this.elderUid,
    required this.elderName,
    required this.fallbackLatitude,
    required this.fallbackLongitude,
  });

  final String elderUid;
  final String elderName;
  final double? fallbackLatitude;
  final double? fallbackLongitude;

  Stream<LatLng> _caregiverLocationStream() async* {
    final initial = await LocationService.instance.getCurrentLatLng();
    yield initial;

    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).map((position) => LatLng(position.latitude, position.longitude));
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(meters >= 10000 ? 0 : 1)} กม.';
    }
    return '${meters.toStringAsFixed(meters >= 100 ? 0 : 1)} เมตร';
  }

  double _distanceMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * 3.141592653589793 / 180.0;
    final dLng = (lng2 - lng1) * 3.141592653589793 / 180.0;
    final a =
        (0.5 - (cos(dLat) / 2)) +
        cos(lat1 * 3.141592653589793 / 180.0) *
            cos(lat2 * 3.141592653589793 / 180.0) *
            (0.5 - (cos(dLng) / 2));
    return earthRadius * 2 * asin(sqrt(a));
  }

  @override
  Widget build(BuildContext context) {
    final liveStream = FirebaseFirestore.instance
        .collection('live_locations')
        .doc(elderUid)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: liveStream,
      builder: (context, elderSnap) {
        final liveData = elderSnap.data?.data() ?? <String, dynamic>{};
        final elderLat = (liveData['lat'] as num?)?.toDouble() ?? fallbackLatitude;
        final elderLng = (liveData['lng'] as num?)?.toDouble() ?? fallbackLongitude;

        return StreamBuilder<LatLng>(
          stream: _caregiverLocationStream(),
          builder: (context, caregiverSnap) {
            String value;
            Color valueColor = AppColors.text;

            if (elderLat == null || elderLng == null) {
              value = 'ยังไม่พบตำแหน่งผู้สูงอายุ';
              valueColor = AppColors.subtleText;
            } else if (caregiverSnap.hasError) {
              value = 'เปิดตำแหน่งคนใกล้ชิดเพื่อคำนวณ';
              valueColor = Colors.orange.shade800;
            } else if (!caregiverSnap.hasData) {
              value = 'กำลังคำนวณ...';
              valueColor = AppColors.subtleText;
            } else {
              final caregiverLatLng = caregiverSnap.data!;
              final meters = _distanceMeters(
                lat1: caregiverLatLng.latitude,
                lng1: caregiverLatLng.longitude,
                lat2: elderLat,
                lng2: elderLng,
              );
              value = _formatDistance(meters);
            }

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.social_distance_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ระยะห่างคนใกล้ชิด-ผู้สูงอายุ',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.subtleText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: valueColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'อัปเดตแบบเรียลไทม์เทียบกับตำแหน่งล่าสุดของ $elderName',
                          style: const TextStyle(
                            color: AppColors.subtleText,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  const _SummaryMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 128),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.subtleText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}



class _NotificationRequestTile extends StatelessWidget {
  const _NotificationRequestTile({
    required this.elderUid,
    required this.onAccept,
    required this.onReject,
  });

  final String elderUid;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: db.collection('users').doc(elderUid).get(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? <String, dynamic>{};
        final fullName = (data['fullName'] ?? '').toString().trim();
        final identifier = (data['identifier'] ?? elderUid).toString();
        final phone = (data['phone'] ?? '').toString();
        final displayName = fullName.isNotEmpty ? fullName : identifier;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 24,
                child: Icon(Icons.person_add_alt_1_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ส่งคำขอเป็นคนใกล้ชิดถึงคุณ',
                      style: TextStyle(color: AppColors.subtleText),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'โทร: $phone',
                        style: const TextStyle(color: AppColors.subtleText),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: onAccept,
                          icon: const Icon(Icons.check, size: 22),
                          label: const Text('ยอมรับ'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            textStyle: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: onReject,
                          icon: const Icon(Icons.close, size: 22),
                          label: const Text('ปฏิเสธ'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            textStyle: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ElderRequestTile extends StatelessWidget {
  const _ElderRequestTile({super.key,
    required this.elderUid,
    required this.onAccept,
    required this.onReject,
  });

  final String elderUid;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: db.collection('users').doc(elderUid).get(),
      builder: (context, snap) {
        // ✅ ระหว่างโหลด: แสดง placeholder ไม่ให้โชว์ UID มั่วๆ
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person_outline)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('กำลังโหลดข้อมูล...', style: TextStyle(color: AppColors.subtleText)),
                ),
                Column(
                  children: [
                    ElevatedButton(onPressed: null, child: const Text('ยอมรับ')),
                    const SizedBox(height: 6),
                    OutlinedButton(onPressed: null, child: const Text('ปฏิเสธ')),
                  ],
                ),
              ],
            ),
          );
        }

        if (!snap.hasData || !snap.data!.exists) {
          // ✅ ถ้าไม่เจอ user จริงๆ ค่อย fallback เป็น UID
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person_outline)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(elderUid, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const Text('ไม่พบข้อมูลผู้ใช้', style: TextStyle(color: AppColors.subtleText)),
                    ],
                  ),
                ),
                Column(
                  children: [
                    ElevatedButton(onPressed: onAccept, child: const Text('ยอมรับ')),
                    const SizedBox(height: 6),
                    OutlinedButton(onPressed: onReject, child: const Text('ปฏิเสธ')),
                  ],
                ),
              ],
            ),
          );
        }

        final data = snap.data!.data() ?? <String, dynamic>{};
        final fullName = (data['fullName'] ?? '').toString();
        final identifier = (data['identifier'] ?? elderUid).toString();
        final phone = (data['phone'] ?? '').toString();

        final displayName = fullName.isNotEmpty ? fullName : identifier;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const CircleAvatar(child: Icon(Icons.person_outline)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('ชื่อผู้ใช้: $identifier', style: const TextStyle(color: AppColors.subtleText)),
                    if (phone.isNotEmpty)
                      Text('โทร: $phone', style: const TextStyle(color: AppColors.subtleText)),
                    const Text('สถานะ: รอการยอมรับ', style: TextStyle(color: AppColors.subtleText)),
                  ],
                ),
              ),
              Column(
                children: [
                  ElevatedButton(onPressed: onAccept, child: const Text('ยอมรับ')),
                  const SizedBox(height: 6),
                  OutlinedButton(onPressed: onReject, child: const Text('ปฏิเสธ')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}



class _ElderTile extends StatefulWidget {
  const _ElderTile({super.key, required this.elderUid, required this.onRemove});

  final String elderUid;
  final VoidCallback onRemove;

  @override
  State<_ElderTile> createState() => _ElderTileState();
}

class _ElderTileState extends State<_ElderTile> {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  void _openHistory(BuildContext context, String displayName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ElderLocationHistoryScreen(
          elderUid: widget.elderUid,
          elderName: displayName,
        ),
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _callNumber(BuildContext context, String phone, {String? emptyMessage}) async {
    final cleanedPhone = phone.trim();
    if (cleanedPhone.isEmpty) {
      _showSnack(context, emptyMessage ?? 'ยังไม่มีเบอร์โทร');
      return;
    }

    try {
      await launchUrl(
        Uri.parse('tel:$cleanedPhone'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (!context.mounted) return;
      _showSnack(context, 'ไม่สามารถเปิดหน้าจอโทรศัพท์ได้');
    }
  }

  Future<Map<String, double>?> _getLatestCoordinates() async {
    double? lat;
    double? lng;

    final liveSnap = await _db.collection('live_locations').doc(widget.elderUid).get();
    final liveData = liveSnap.data();
    if (liveData != null) {
      lat = (liveData['lat'] as num?)?.toDouble();
      lng = (liveData['lng'] as num?)?.toDouble();
    }

    if (lat == null || lng == null) {
      final historySnap = await _db
          .collection('users')
          .doc(widget.elderUid)
          .collection('location_history')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (historySnap.docs.isNotEmpty) {
        final historyData = historySnap.docs.first.data();
        lat = (historyData['lat'] as num?)?.toDouble();
        lng = (historyData['lng'] as num?)?.toDouble();
      }
    }

    if (lat == null || lng == null) return null;
    return {'lat': lat, 'lng': lng};
  }

  Future<void> _navigateToElder(BuildContext context, String displayName) async {
    try {
      final coords = await _getLatestCoordinates();
      if (coords == null) {
        if (!context.mounted) return;
        _showSnack(context, 'ยังไม่พบตำแหน่งล่าสุดของ $displayName');
        return;
      }

      final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${coords['lat']},${coords['lng']}',
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!context.mounted) return;
      _showSnack(context, 'ไม่สามารถเปิดการนำทางได้');
    }
  }

  double _distanceMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * 3.141592653589793 / 180.0;
    final dLng = (lng2 - lng1) * 3.141592653589793 / 180.0;
    final a =
        (0.5 - (cos(dLat) / 2)) +
        cos(lat1 * 3.141592653589793 / 180.0) *
            cos(lat2 * 3.141592653589793 / 180.0) *
            (0.5 - (cos(dLng) / 2));
    return earthRadius * 2 * asin(sqrt(a));
  }

  Widget _actionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool primary = false,
  }) {
    final color = Theme.of(context).colorScheme.primary;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: primary ? AppColors.card : color,
        backgroundColor: primary ? color : AppColors.card,
        side: BorderSide(color: color.withValues(alpha: primary ? 0 : 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        minimumSize: const Size(0, 42),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }


  InputDecoration _dialogInputDecoration(String label) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return InputDecoration(
      labelText: label,
      alignLabelWithHint: true,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Future<void> _showEmergencyContactEditor(BuildContext context, {DocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final nameController = TextEditingController(text: (doc?.data()?['name'] ?? '').toString());
    final relationController = TextEditingController(text: (doc?.data()?['relationship'] ?? '').toString());
    final phoneController = TextEditingController(text: (doc?.data()?['phone'] ?? '').toString());
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(doc == null ? 'เพิ่มผู้ติดต่อฉุกเฉิน' : 'แก้ไขผู้ติดต่อฉุกเฉิน'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: _dialogInputDecoration('ชื่อ'),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'กรอกชื่อ' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: relationController,
                  decoration: _dialogInputDecoration('ความสัมพันธ์'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  decoration: _dialogInputDecoration('เบอร์โทร'),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (value) {
                    final phone = (value ?? '').trim();
                    if (phone.isEmpty) return 'กรอกเบอร์โทร';
                    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
                      return 'เบอร์โทรต้องเป็นตัวเลข 10 หลัก';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final contactRef = doc == null
                  ? _db.collection('users').doc(widget.elderUid).collection('emergency_contacts').doc()
                  : _db.collection('users').doc(widget.elderUid).collection('emergency_contacts').doc(doc.id);
              await contactRef.set({
                'name': nameController.text.trim(),
                'relationship': relationController.text.trim(),
                'phone': phoneController.text.replaceAll(RegExp(r'\D'), '').trim(),
                'updatedAt': FieldValue.serverTimestamp(),
                if (doc == null) 'createdAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (saved == true && context.mounted) {
      _showSnack(context, 'บันทึกผู้ติดต่อฉุกเฉินแล้ว');
    }
  }

  Future<void> _deleteEmergencyContact(BuildContext context, String contactId) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('ลบผู้ติดต่อฉุกเฉิน'),
            content: const Text('ต้องการลบผู้ติดต่อฉุกเฉินนี้ใช่หรือไม่'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('ลบ'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;
    await _db.collection('users').doc(widget.elderUid).collection('emergency_contacts').doc(contactId).delete();
    if (!context.mounted) return;
    _showSnack(context, 'ลบผู้ติดต่อฉุกเฉินแล้ว');
  }

  Future<void> _showGeofenceEditor(BuildContext context, {Map<String, dynamic>? currentData}) async {
    final nameController = TextEditingController(text: (currentData?['name'] ?? '').toString());
    final radiusController = TextEditingController(
      text: ((currentData?['radiusMeters'] as num?)?.toInt() ?? 300).toString(),
    );
    bool enabled = (currentData?['enabled'] ?? true) == true;
    Map<String, double>? center;

    if (currentData?['centerLat'] != null && currentData?['centerLng'] != null) {
      center = {
        'lat': (currentData!['centerLat'] as num).toDouble(),
        'lng': (currentData['centerLng'] as num).toDouble(),
      };
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('ตั้งค่า Geofence'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: _dialogInputDecoration('ชื่อพื้นที่ เช่น บ้าน'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: radiusController,
                      decoration: _dialogInputDecoration('รัศมี (เมตร)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: enabled,
                      title: const Text('เปิดใช้งาน Geofence'),
                      onChanged: (value) => setDialogState(() => enabled = value),
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (_) {
                        final centerLatValue = center?['lat'];
                        final centerLngValue = center?['lng'];
                        return Text(
                          centerLatValue == null || centerLngValue == null
                              ? 'ยังไม่ได้ตั้งศูนย์กลางพื้นที่'
                              : 'ศูนย์กลาง: ${centerLatValue.toStringAsFixed(5)}, ${centerLngValue.toStringAsFixed(5)}',
                          style: const TextStyle(color: AppColors.subtleText),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                      onPressed: () async {
                        final latest = await _getLatestCoordinates();
                        if (latest == null) {
                          if (!dialogContext.mounted) return;
                          _showSnack(context, 'ยังไม่พบตำแหน่งล่าสุดสำหรับตั้งศูนย์กลาง');
                          return;
                        }
                        setDialogState(() => center = latest);
                      },
                      icon: const Icon(Icons.my_location),
                      label: const Text('ใช้ตำแหน่งล่าสุดเป็นศูนย์กลาง'),
                    ),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  onPressed: () async {
                    final radius = int.tryParse(radiusController.text.trim()) ?? 300;
                    await _db.collection('users').doc(widget.elderUid).collection('settings').doc('geofence').set({
                      'name': nameController.text.trim().isEmpty ? 'พื้นที่ปลอดภัย' : nameController.text.trim(),
                      'radiusMeters': radius,
                      'enabled': enabled,
                      'centerLat': center?['lat'],
                      'centerLng': center?['lng'],
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('บันทึก'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && context.mounted) {
      _showSnack(context, 'บันทึก Geofence แล้ว');
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours >= 1) {
      return '${duration.inHours} ชม.';
    }
    if (duration.inMinutes >= 1) {
      return '${duration.inMinutes} นาที';
    }
    return '${duration.inSeconds} วินาที';
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final userStream = db.collection('users').doc(widget.elderUid).snapshots();
    final liveStream = db.collection('live_locations').doc(widget.elderUid).snapshots();
    final geofenceStream = db.collection('users').doc(widget.elderUid).collection('settings').doc('geofence').snapshots();
    final contactsStream = db
        .collection('users')
        .doc(widget.elderUid)
        .collection('emergency_contacts')
        .orderBy('createdAt', descending: false)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userStream,
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting && !userSnap.hasData) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: const [
                CircleAvatar(child: Icon(Icons.person)),
                SizedBox(width: 12),
                Expanded(child: Text('กำลังโหลดข้อมูล...', style: TextStyle(color: AppColors.subtleText))),
              ],
            ),
          );
        }

        final userData = userSnap.data?.data() ?? <String, dynamic>{};
        final fullName = (userData['fullName'] ?? '').toString();
        final identifier = (userData['identifier'] ?? widget.elderUid).toString();
        final phone = (userData['phone'] ?? '').toString();
        final displayName = fullName.isNotEmpty ? fullName : identifier;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: liveStream,
          builder: (context, liveSnap) {
            final liveData = liveSnap.data?.data() ?? <String, dynamic>{};
            final isSharing = (liveData['isSharing'] ?? false) == true;
            final lat = (liveData['lat'] as num?)?.toDouble();
            final lng = (liveData['lng'] as num?)?.toDouble();
            final ts = liveData['updatedAt'] ?? liveData['timestamp'];
            DateTime? lastUpdate;
            if (ts is Timestamp) lastUpdate = ts.toDate();

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: geofenceStream,
              builder: (context, geoSnap) {
                final geoData = geoSnap.data?.data() ?? <String, dynamic>{};
                final geofenceEnabled = (geoData['enabled'] ?? false) == true;
                final centerLat = (geoData['centerLat'] as num?)?.toDouble();
                final centerLng = (geoData['centerLng'] as num?)?.toDouble();
                final radius = (geoData['radiusMeters'] as num?)?.toDouble() ?? 0;
                final geofenceName = (geoData['name'] ?? 'พื้นที่ปลอดภัย').toString();

                bool isOutsideGeofence = false;
                if (geofenceEnabled && lat != null && lng != null && centerLat != null && centerLng != null && radius > 0) {
                  final meters = _distanceMeters(
                    lat1: lat,
                    lng1: lng,
                    lat2: centerLat,
                    lng2: centerLng,
                  );
                  isOutsideGeofence = meters > radius;
                }

                final now = DateTime.now();
                final baseAlerts = <String>[];
                if (!isSharing) {
                  baseAlerts.add('ยังไม่ได้เปิดแชร์ตำแหน่ง');
                }
                if (lastUpdate == null) {
                  baseAlerts.add('ยังไม่มีตำแหน่งล่าสุด');
                } else {
                  final age = now.difference(lastUpdate);
                  if (age.inMinutes >= 30) {
                    baseAlerts.add('ตำแหน่งไม่อัปเดตมา ${_formatDuration(age)}');
                  }
                }
                if (geofenceEnabled && (centerLat == null || centerLng == null)) {
                  baseAlerts.add('เปิด Geofence แล้วแต่ยังไม่ได้ตั้งศูนย์กลาง');
                }
                if (isOutsideGeofence) {
                  baseAlerts.add('ออกนอก $geofenceName');
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: contactsStream,
                  builder: (context, contactSnap) {
                    final contacts = contactSnap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    final alerts = <String>[
                      ...baseAlerts,
                      if (contacts.isEmpty) 'ยังไม่มีผู้ติดต่อฉุกเฉิน',
                    ];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFFEADCFB),
                                child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary, size: 30),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'ชื่อผู้ใช้: $identifier',
                                      style: const TextStyle(color: AppColors.subtleText, fontSize: 22),
                                    ),
                                    if (phone.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          'โทร: $phone',
                                          style: const TextStyle(color: AppColors.subtleText, fontSize: 22),
                                        ),
                                      ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _statusChip(
                                          label: isSharing ? 'แชร์ตำแหน่งอยู่' : 'ไม่แชร์ตำแหน่ง',
                                          color: isSharing ? Colors.green : Colors.orange,
                                        ),
                                        _statusChip(
                                          label: geofenceEnabled ? 'มี Geofence' : 'ยังไม่ตั้ง Geofence',
                                          color: geofenceEnabled ? Colors.blue : Colors.grey,
                                        ),
                                        _statusChip(
                                          label: 'ผู้ติดต่อฉุกเฉิน ${contacts.length}',
                                          color: contacts.isNotEmpty ? Colors.teal : Colors.redAccent,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: widget.onRemove,
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'ออกจากการดูแล',
                                color: AppColors.subtleText,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (alerts.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF4E5),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFFD39A)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
                                      SizedBox(width: 6),
                                      Text(
                                        'แจ้งเตือนผิดปกติ',
                                        style: TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...alerts.map((message) => Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text('• $message'),
                                      )),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _actionButton(
                                context: context,
                                icon: Icons.call_outlined,
                                label: 'โทรหา',
                                onPressed: () => _callNumber(context, phone, emptyMessage: 'ยังไม่มีเบอร์โทรของผู้สูงอายุ'),
                                primary: true,
                              ),
                              _actionButton(
                                context: context,
                                icon: Icons.navigation_outlined,
                                label: 'นำทาง',
                                onPressed: () => _navigateToElder(context, displayName),
                              ),
                              _actionButton(
                                context: context,
                                icon: Icons.history,
                                label: 'ดูประวัติ',
                                onPressed: () => _openHistory(context, displayName),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _sectionCard(
                            title: 'Geofence',
                            icon: Icons.my_location,
                            trailing: TextButton.icon(
                              onPressed: () => _showGeofenceEditor(context, currentData: geoData),
                              icon: const Icon(Icons.edit_outlined),
                              label: Text(geoSnap.data?.exists == true ? 'แก้ไข' : 'ตั้งค่า'),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  geoSnap.data?.exists == true
                                      ? '${geofenceEnabled ? 'เปิดใช้งาน' : 'ปิดใช้งาน'} • $geofenceName • รัศมี ${radius.toInt()} ม.'
                                      : 'ยังไม่ได้ตั้งค่า Geofence',
                                  style: const TextStyle(color: AppColors.text),
                                ),
                                if (centerLat != null && centerLng != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'ศูนย์กลาง: ${centerLat.toStringAsFixed(5)}, ${centerLng.toStringAsFixed(5)}',
                                      style: const TextStyle(color: AppColors.subtleText, fontSize: 22),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _sectionCard(
                            title: 'ผู้ติดต่อฉุกเฉิน',
                            icon: Icons.contact_phone_outlined,
                            trailing: TextButton.icon(
                              onPressed: () => _showEmergencyContactEditor(context),
                              icon: const Icon(Icons.add),
                              label: const Text('เพิ่ม'),
                            ),
                            child: contacts.isEmpty
                                ? const Text('ยังไม่มีผู้ติดต่อฉุกเฉิน', style: TextStyle(color: AppColors.subtleText))
                                : Column(
                                    children: contacts.map((contactDoc) {
                                      final contact = contactDoc.data();
                                      final contactName = (contact['name'] ?? '').toString();
                                      final relationship = (contact['relationship'] ?? '').toString();
                                      final contactPhone = (contact['phone'] ?? '').toString();
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8F7FB),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    contactName.isEmpty ? 'ไม่ระบุชื่อ' : contactName,
                                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                                  ),
                                                  if (relationship.isNotEmpty)
                                                    Text(relationship, style: const TextStyle(color: AppColors.subtleText)),
                                                  if (contactPhone.isNotEmpty)
                                                    Text(contactPhone, style: const TextStyle(color: AppColors.subtleText)),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () => _callNumber(context, contactPhone),
                                              icon: const Icon(Icons.call_outlined),
                                              tooltip: 'โทร',
                                            ),
                                            IconButton(
                                              onPressed: () => _showEmergencyContactEditor(context, doc: contactDoc),
                                              icon: const Icon(Icons.edit_outlined),
                                              tooltip: 'แก้ไข',
                                            ),
                                            IconButton(
                                              onPressed: () => _deleteEmergencyContact(context, contactDoc.id),
                                              icon: const Icon(Icons.delete_outline),
                                              tooltip: 'ลบ',
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _statusChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// แท็บโปรไฟล์ของคนใกล้ชิด (แสดงโปรไฟล์ + ปุ่มเปลี่ยนรหัสผ่านเหมือนเดิม)
class CaregiverProfileTab extends StatelessWidget {
  final VoidCallback onChangePassword;

  const CaregiverProfileTab({
    super.key,
    required this.onChangePassword,
  });

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _connectTelegram(BuildContext context) async {
    final ok = await TelegramConnectService.openConnectBot();
    if (!context.mounted) return;

    if (!ok) {
      _showSnack(
        context,
        'เปิด LINE ไม่สำเร็จ',
      );
      return;
    }

    _showSnack(
      context,
      'เปิด LINE แล้วส่งข้อความที่ระบบเตรียมไว้เพื่อเชื่อมการแจ้งเตือน',
    );
  }

  Future<void> _copyLinkCommand(BuildContext context) async {
    final message = TelegramConnectService.buildLinkMessage();
    if (message == null) {
      _showSnack(context, 'ไม่พบผู้ใช้งานปัจจุบัน');
      return;
    }

    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) return;
    _showSnack(context, 'คัดลอกคำสั่งเชื่อม LINE แล้ว');
  }

  Future<void> _disconnectTelegram(BuildContext context) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      _showSnack(context, 'ไม่พบผู้ใช้งานปัจจุบัน');
      return;
    }

    final confirm = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('ยกเลิกเชื่อมต่อ LINE'),
            content: const Text(
              'หลังยกเลิกเชื่อมต่อ ระบบจะหยุดส่งการแจ้งเตือน LINE ไปยังบัญชีนี้ทันที',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('ยืนยัน'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    await FirebaseFirestore.instance.collection('users').doc(me.uid).set({
      'lineConnected': false,
      'lineUserId': FieldValue.delete(),
      'lineDisplayName': FieldValue.delete(),
      'lineLanguage': FieldValue.delete(),
      'linePictureUrl': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!context.mounted) return;
    _showSnack(context, 'ยกเลิกเชื่อมต่อ LINE แล้ว');
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;

    return Padding(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          const Expanded(child: ProfileScreen()),
          if (me != null)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(me.uid).snapshots(),
              builder: (context, snap) {
                final data = snap.data?.data() ?? const <String, dynamic>{};
                final connected = (data['lineConnected'] ?? false) == true;
                final chatId = (data['lineUserId'] ?? '').toString();
                final lineDisplayName = (data['lineDisplayName'] ?? '').toString();
                final linkMessage = TelegramConnectService.buildLinkMessage() ?? 'LINK caregiver_<uid>';

                return SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _DraggableLineConnectCard(
                      connected: connected,
                      chatId: chatId,
                      lineDisplayName: lineDisplayName,
                      linkMessage: linkMessage,
                      onConnect: () => _connectTelegram(context),
                      onDisconnect: connected ? () => _disconnectTelegram(context) : null,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}


class _DraggableLineConnectCard extends StatefulWidget {
  const _DraggableLineConnectCard({
    required this.connected,
    required this.chatId,
    required this.lineDisplayName,
    required this.linkMessage,
    required this.onConnect,
    required this.onDisconnect,
  });

  final bool connected;
  final String chatId;
  final String lineDisplayName;
  final String linkMessage;
  final VoidCallback onConnect;
  final VoidCallback? onDisconnect;

  @override
  State<_DraggableLineConnectCard> createState() => _DraggableLineConnectCardState();
}

class _DraggableLineConnectCardState extends State<_DraggableLineConnectCard> {
  static const double _collapsedHeight = 164;
  static const double _expandedHeight = 350;
  static const double _dragSensitivity = 1.0;

  late double _currentHeight;

  @override
  void initState() {
    super.initState();
    _currentHeight = _collapsedHeight;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _currentHeight = (_currentHeight - (details.delta.dy * _dragSensitivity))
          .clamp(_collapsedHeight, _expandedHeight);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final halfway = (_collapsedHeight + _expandedHeight) / 2;
    setState(() {
      _currentHeight = _currentHeight >= halfway ? _expandedHeight : _collapsedHeight;
    });
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.connected;
    final statusText = connected
        ? 'เชื่อมต่อแล้ว${widget.chatId.isNotEmpty ? ' • userId: ${widget.chatId}' : ''}'
        : 'ยังไม่ได้เชื่อมต่อ LINE';
    final helperText = connected
        ? 'ลากแถบบนลงเพื่อย่อกล่องนี้ หรือยกเลิกเชื่อมต่อ LINE ได้จากปุ่มด้านล่าง'
        : 'ลากแถบบนขึ้นเพื่อดูรายละเอียดการเชื่อม LINE เพิ่มเติม';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: _currentHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: _handleDragUpdate,
            onVerticalDragEnd: _handleDragEnd,
            onTap: () {
              setState(() {
                _currentHeight = _currentHeight == _collapsedHeight
                    ? _expandedHeight
                    : _collapsedHeight;
              });
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'การแจ้งเตือน LINE',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Icon(
                        _currentHeight == _collapsedHeight
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: AppColors.subtleText,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      statusText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: connected ? Colors.green.shade700 : AppColors.subtleText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LINE OA: ${TelegramConnectService.officialAccountId}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            'ข้อความเชื่อม: ${widget.linkMessage}',
                            style: const TextStyle(color: AppColors.subtleText),
                          ),
                          if (connected && widget.lineDisplayName.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'ชื่อบน LINE: ${widget.lineDisplayName}',
                              style: const TextStyle(color: AppColors.subtleText),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: widget.onConnect,
                        icon: const Icon(Icons.send),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(connected ? 'เชื่อมใหม่อีกครั้ง' : 'เชื่อม LINE'),
                        ),
                      ),
                    ),
                    if (widget.onDisconnect != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: widget.onDisconnect,
                          icon: const Icon(Icons.link_off),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('ยกเลิกเชื่อมต่อ LINE'),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      helperText,
                      style: const TextStyle(fontSize: 13, color: AppColors.subtleText),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
