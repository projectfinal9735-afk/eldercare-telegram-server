import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart';
import 'change_password_screen.dart';
import 'route_search_screen.dart';
import 'elder_location_history_screen.dart';
import '../root.dart';
import '../services/telegram_connect_service.dart';



class HomeCaregiverScreen extends StatefulWidget {
  const HomeCaregiverScreen({super.key});

  @override
  State<HomeCaregiverScreen> createState() => _HomeCaregiverScreenState();
}

class _HomeCaregiverScreenState extends State<HomeCaregiverScreen> {
  // ✅ ให้เข้าแท็บโปรไฟล์หลัง login เหมือนเดิม
  int _index = 2;

  String get _title {
    switch (_index) {
      case 0:
        return 'ผู้สูงอายุที่ดูแล';
      case 1:
        return 'แผนที่';
      case 2:
        return 'ข้อมูลส่วนตัว (ผู้ดูแล)';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const CaregiverEldersScreen(),
      const RouteSearchScreen(showCoordinateInput: true),
      CaregiverProfileTab(onChangePassword: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
        );
      }),
    ];

    return Scaffold(
      appBar: AppBar(
  backgroundColor: const Color.fromARGB(255, 239, 150, 91), // ✅ ฟ้าเดียวกับแถบล่าง
  elevation: 0,
  title: Text(
    _title,
    style: const TextStyle(
      color: Colors.white, // ✅ ตัวหนังสือขาว
      fontWeight: FontWeight.w600,
    ),
  ),
  iconTheme: const IconThemeData(
    color: Colors.white, // ✅ ไอคอนฝั่งซ้าย
  ),
  actionsIconTheme: const IconThemeData(
    color: Colors.white, // ✅ ไอคอนฝั่งขวา
  ),
  actions: [
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
    final color = Colors.white; // ✅ บังคับให้เป็นสีขาว

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 239, 150, 91), // ✅ พื้นหลังฟ้า (เหมือนปุ่มไป)
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            _button(
              icon: Icons.person_add_alt_1,
              label: 'ผู้ดูแล',
              selected: currentIndex == 0,
              color: color,
              onTap: () => onSelect(0),
            ),
            _button(
              icon: Icons.map,
              label: 'แผนที่',
              selected: currentIndex == 1,
              color: color,
              onTap: () => onSelect(1),
            ),
            _button(
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

  Widget _button({
    required IconData icon,
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 30,
                color: selected ? color : color.withOpacity(0.7),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? color : color.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// placeholder: รายชื่อผู้สูงอายุที่ผู้ดูแลดูแลอยู่
class CaregiverEldersScreen extends StatefulWidget {
  const CaregiverEldersScreen({super.key});

  @override
  State<CaregiverEldersScreen> createState() => _CaregiverEldersScreenState();
}

class _CaregiverEldersScreenState extends State<CaregiverEldersScreen> {
  User? get _me => FirebaseAuth.instance.currentUser;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
  Future<void> caregiverRemoveElder(String elderUid) async {
    final me = _me;
    if (me == null) return;

    try {
      // ✅ caregiver ลบ elder ออกจากรายการของตัวเอง (ไม่ต้องแก้ doc ของ elder)
      await _db.collection('users').doc(me.uid).update({
        'elderIds': FieldValue.arrayRemove([elderUid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ✅ เคลียร์สถานะคำขอเดิม (กันค้าง accepted ทำให้แอดใหม่ไม่ได้)
      final reqId = '${elderUid}_${me.uid}';
      await _db.collection('caregiver_requests').doc(reqId).set({
        'status': 'canceled', // หรือ 'removed'
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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

    final batch = _db.batch();

    // 1) อัปเดตสถานะคำขอ
    batch.set(reqRef, {
      'elderId': elderUid,
      'caregiverId': caregiverUid,
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2) เพิ่มความสัมพันธ์ 2 ฝั่ง (ใช้ update จะตรง rules กว่า)
    batch.update(elderRef, {
      'caregiverIds': FieldValue.arrayUnion([caregiverUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(caregiverRef, {
      'elderIds': FieldValue.arrayUnion([elderUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    _snack('ยอมรับคำขอแล้ว');
  } on FirebaseException catch (e) {
    _snack(e.message ?? 'ยอมรับไม่สำเร็จ');
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
              'คำขอเป็นผู้ดูแล (รอการตอบรับ)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final elderUid = (data['elderId'] ?? '').toString();
              return _ElderRequestTile(
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
    return StreamBuilder<DocumentSnapshot>(
      stream: caregiverDoc.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = (snap.data?.data() as Map<String, dynamic>?) ?? {};
        final ids = (data['elderIds'] as List?)?.cast<String>() ?? const <String>[];

        if (ids.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'ยังไม่มีผู้สูงอายุที่คุณดูแล\nเมื่อ Elder ส่งคำขอมา คุณสามารถกดยอมรับได้ที่ด้านบน',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ผู้สูงอายุที่คุณดูแล',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...ids.map((eid) => _ElderTile(elderUid: eid, onRemove: () => caregiverRemoveElder(eid))),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _pendingRequests(),
          _acceptedElders(),
          const SizedBox(height: 24),
          const Text(
            'หมายเหตุ: Elder ต้องส่งคำขอ และคุณต้องกด “ยอมรับ” ก่อนถึงจะเชื่อมกัน',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _ElderRequestTile extends StatelessWidget {
  const _ElderRequestTile({
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
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person_outline)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('กำลังโหลดข้อมูล...', style: TextStyle(color: Colors.black54)),
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
              border: Border.all(color: Colors.black12),
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
                      const Text('ไม่พบข้อมูลผู้ใช้', style: TextStyle(color: Colors.black54)),
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
            border: Border.all(color: Colors.black12),
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
                    Text('ชื่อผู้ใช้: $identifier', style: const TextStyle(color: Colors.black54)),
                    if (phone.isNotEmpty)
                      Text('โทร: $phone', style: const TextStyle(color: Colors.black54)),
                    const Text('สถานะ: รอการยอมรับ', style: TextStyle(color: Colors.black54)),
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


class _ElderTile extends StatelessWidget {
  const _ElderTile({required this.elderUid, required this.onRemove});

  final String elderUid;
  final VoidCallback onRemove;

  void _openHistory(BuildContext context, String displayName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ElderLocationHistoryScreen(
          elderUid: elderUid,
          elderName: displayName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: db.collection('users').doc(elderUid).get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('กำลังโหลดข้อมูล...', style: TextStyle(color: Colors.black54)),
                ),
              ],
            ),
          );
        }

        final data = snap.data?.data() ?? <String, dynamic>{};
        final fullName = (data['fullName'] ?? '').toString();
        final identifier = (data['identifier'] ?? elderUid).toString();
        final phone = (data['phone'] ?? '').toString();

        final displayName = fullName.isNotEmpty ? fullName : identifier;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const CircleAvatar(child: Icon(Icons.person)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('ชื่อผู้ใช้: $identifier', style: const TextStyle(color: Colors.black54)),
                    if (phone.isNotEmpty)
                      Text('โทร: $phone', style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openHistory(context, displayName),
                    icon: const Icon(Icons.history),
                    label: const Text('ดูประวัติ'),
                  ),
                  const SizedBox(height: 6),
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'ออกจากการดูแล',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}


/// แท็บโปรไฟล์ของผู้ดูแล (แสดงโปรไฟล์ + ปุ่มเปลี่ยนรหัสผ่านเหมือนเดิม)
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
        TelegramConnectService.botUsername == 'YOUR_BOT_USERNAME'
            ? 'กรุณาตั้งค่า Telegram bot username ก่อน'
            : 'เปิด Telegram ไม่สำเร็จ',
      );
      return;
    }

    _showSnack(
      context,
      'เปิด Telegram แล้ว กด Start กับบอตเพื่อเชื่อมการแจ้งเตือน',
    );
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
                final connected = (data['telegramConnected'] ?? false) == true;
                final chatId = (data['telegramChatId'] ?? '').toString();

                return SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'การแจ้งเตือน Telegram',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                connected
                                    ? 'เชื่อมต่อแล้ว${chatId.isNotEmpty ? ' • chatId: $chatId' : ''}'
                                    : 'ยังไม่ได้เชื่อมต่อ Telegram',
                                style: TextStyle(
                                  color: connected ? Colors.green.shade700 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _connectTelegram(context),
                                  icon: const Icon(Icons.send),
                                  label: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Text(connected ? 'เชื่อมใหม่อีกครั้ง' : 'เชื่อม Telegram'),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'เมื่อกดปุ่ม ระบบจะเปิด Telegram ให้กด Start กับบอต 1 ครั้ง',
                                style: TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: onChangePassword,
                            icon: const Icon(Icons.lock_reset),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text('เปลี่ยนรหัสผ่าน', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                        ),
                      ],
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
