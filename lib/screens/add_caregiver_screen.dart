import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// หน้า Elder: แอดเพื่อนผู้ดูแล (Caregiver) แบบ "ส่งคำขอ" แล้วให้ฝั่งผู้ดูแลกดยอมรับ/ปฏิเสธ
///
/// โครงสร้างข้อมูล:
/// - users/{elderUid}.caregiverIds = [caregiverUid, ...]        // เฉพาะที่ "ยอมรับแล้ว"
/// - users/{caregiverUid}.elderIds = [elderUid, ...]           // เฉพาะที่ "ยอมรับแล้ว"
/// - caregiver_requests/{elderUid}_{caregiverUid}
///   { elderId, caregiverId, status: pending|accepted|rejected|canceled, createdAt, updatedAt }
///
/// ค้นหา caregiver ด้วย "ชื่อผู้ใช้ (identifier)" ที่ caregiver สมัครไว้
class AddCaregiverScreen extends StatefulWidget {
  const AddCaregiverScreen({super.key});

  @override
  State<AddCaregiverScreen> createState() => _AddCaregiverScreenState();
}

class _AddCaregiverScreenState extends State<AddCaregiverScreen> {
  final _searchCtl = TextEditingController();
  bool _searching = false;
  Map<String, dynamic>? _found;
  String? _foundUid;

  /// เก็บสถานะคำขอระหว่าง Elder -> Caregiver ที่ค้นพบล่าสุด
  String? _foundRequestStatus;

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  User? get _me => FirebaseAuth.instance.currentUser;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    final me = _me;
    if (me == null) {
      _snack('กรุณาเข้าสู่ระบบก่อน');
      return;
    }

    final keyword = _searchCtl.text.trim();
    if (keyword.isEmpty) {
      _snack('กรุณากรอกชื่อผู้ใช้ผู้ดูแล');
      return;
    }

    setState(() {
      _searching = true;
      _found = null;
      _foundUid = null;
    });

    try {
      final qs = await _db
          .collection('users')
          .where('role', isEqualTo: 'caregiver')
          .where('identifier', isEqualTo: keyword)
          .limit(1)
          .get();

      if (qs.docs.isEmpty) {
        if (!mounted) return;
        setState(() {
          _found = null;
          _foundUid = null;
        });
        _snack('ไม่พบผู้ดูแลที่ใช้ชื่อผู้ใช้นี้');
        return;
      }

      final doc = qs.docs.first;

      // ตรวจสอบสถานะคำขอ (ถ้ามี)
final reqId = '${me.uid}_${doc.id}';
final reqSnap =
    await _db.collection('caregiver_requests').doc(reqId).get();

final Map<String, dynamic>? data = reqSnap.data();
final String? status = data?['status']?.toString();

if (!mounted) return;
setState(() {
  _foundUid = doc.id;
  _found = doc.data();
  _foundRequestStatus = (status == null || status.isEmpty) ? null : status;
});




    } on FirebaseException catch (e) {
      _snack(e.message ?? 'ค้นหาไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _sendRequest() async {
    final me = _me;
    if (me == null) {
      _snack('กรุณาเข้าสู่ระบบก่อน');
      return;
    }
    final caregiverUid = _foundUid;
    if (caregiverUid == null) {
      _snack('กรุณาค้นหาผู้ดูแลก่อน');
      return;
    }

    // ถ้ายอมรับแล้ว ไม่ต้องส่งซ้ำ
    final elderDoc = await _db.collection('users').doc(me.uid).get();
final elderData = elderDoc.data() ?? <String, dynamic>{};
final acceptedIds =
    (elderData['caregiverIds'] as List<dynamic>?)?.cast<String>() ?? const <String>[];

    if (acceptedIds.contains(caregiverUid)) {
      _snack('ผู้ดูแลคนนี้ถูกเพิ่มแล้ว');
      return;
    }

    final reqId = '${me.uid}_$caregiverUid';

    try {
      final now = FieldValue.serverTimestamp();
      await _db.collection('caregiver_requests').doc(reqId).set({
        'elderId': me.uid,
        'caregiverId': caregiverUid,
        'status': 'pending',
        'createdAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _foundRequestStatus = 'pending');
      _snack('ส่งคำขอไปยังผู้ดูแลแล้ว');
    } on FirebaseException catch (e) {
      _snack(e.message ?? 'ส่งคำขอไม่สำเร็จ');
    }
  }

  Future<void> _cancelRequest(String caregiverUid) async {
    final me = _me;
    if (me == null) return;

    try {
      final reqId = '${me.uid}_$caregiverUid';
      await _db.collection('caregiver_requests').doc(reqId).set({
        'status': 'canceled',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        if (_foundUid == caregiverUid) _foundRequestStatus = 'canceled';
      });
      _snack('ยกเลิกคำขอแล้ว');
    } on FirebaseException catch (e) {
      _snack(e.message ?? 'ยกเลิกไม่สำเร็จ');
    }
  }

  Future<void> _removeCaregiver(String caregiverUid) async {
  final me = _me;
  if (me == null) return;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('ลบผู้ดูแล'),
      content: const Text('ต้องการลบผู้ดูแลคนนี้ออกใช่หรือไม่?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ลบ')),
      ],
    ),
  );
  if (ok != true) return;

  try {
    // 1) ลบความสัมพันธ์ฝั่ง elder
    await _db.collection('users').doc(me.uid).update({
      'caregiverIds': FieldValue.arrayRemove([caregiverUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2) ✅ สำคัญ: เคลียร์สถานะคำขอเดิมไม่ให้ค้าง "accepted"
    // เพื่อให้สามารถแอดใหม่ได้
    final reqId = '${me.uid}_$caregiverUid';
    await _db.collection('caregiver_requests').doc(reqId).set({
      'status': 'canceled', // หรือ 'removed'
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _snack('ลบผู้ดูแลแล้ว');
  } on FirebaseException catch (e) {
    _snack(e.message ?? 'ลบไม่สำเร็จ');
  }
}


  Widget _searchBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'เพิ่มผู้ดูแล',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'ชื่อผู้ใช้ผู้ดูแล (username)',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
  Expanded(
    child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 239, 150, 91), // ✅ สีปุ่ม
        foregroundColor: Colors.white,     // ✅ สีไอคอน + ตัวหนังสือ
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      onPressed: _searching ? null : _search,
      icon: _searching
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white), // ✅ วงโหลดสีขาว
              ),
            )
          : const Icon(Icons.search),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          _searching ? 'กำลังค้นหา...' : 'ค้นหา',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ),
  ),
],
          ),

          if (_found != null) ...[
            const SizedBox(height: 12),
            _FoundCard(
              identifier: (_found!['identifier'] ?? '').toString(),
              fullName: (_found!['fullName'] ?? '').toString(),
              phone: (_found!['phone'] ?? '').toString(),
              requestStatus: _foundRequestStatus,
              onSendRequest: _sendRequest,
            ),
          ],
        ],
      ),
    );
  }

  Widget _myPendingRequests() {
    final me = _me;
    if (me == null) return const SizedBox.shrink();

    final q = _db
        .collection('caregiver_requests')
        .where('elderId', isEqualTo: me.uid)
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
              'คำขอที่ส่งแล้ว (รอผู้ดูแลยอมรับ)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...docs.map((d) {
  final data = (d.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
  final caregiverUid = (data['caregiverId'] ?? '').toString();

  return _PendingRequestTile(
    caregiverUid: caregiverUid,
    onCancel: () => _cancelRequest(caregiverUid),
  );
}),

          ],
        );
      },
    );
  }

  Widget _myCaregivers() {
    final me = _me;
    if (me == null) {
      return const Center(child: Text('กรุณาเข้าสู่ระบบก่อน'));
    }

    final elderDoc = _db.collection('users').doc(me.uid);
    return StreamBuilder<DocumentSnapshot>(
      stream: elderDoc.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = (snap.data?.data() as Map<String, dynamic>?) ?? {};
        final ids = (data['caregiverIds'] as List?)?.cast<String>() ?? const <String>[];

        if (ids.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'ยังไม่มีผู้ดูแลที่เพิ่มไว้\nให้ค้นหาและกด “เพิ่มผู้ดูแล” ด้านบน',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const Text(
              'ผู้ดูแลของฉัน',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...ids.map((cid) => _CaregiverTile(
                  caregiverUid: cid,
                  onRemove: () => _removeCaregiver(cid),
                )),
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
          _searchBox(),
          const SizedBox(height: 18),
          _myPendingRequests(),
          const SizedBox(height: 18),
          _myCaregivers(),
          const SizedBox(height: 24),
          const Text(
            'หมายเหตุ: ผู้ดูแลต้องกด “ยอมรับ” ก่อนถึงจะถูกเพิ่มเป็นผู้ดูแลของคุณ',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _FoundCard extends StatelessWidget {
  const _FoundCard({
    required this.identifier,
    required this.fullName,
    required this.phone,
    required this.requestStatus,
    required this.onSendRequest,
  });

  final String identifier;
  final String fullName;
  final String phone;
  final String? requestStatus;
  final VoidCallback onSendRequest;

  @override
  Widget build(BuildContext context) {
    final status = (requestStatus ?? '').toLowerCase();
    final isPending = status == 'pending';
    final isAccepted = status == 'accepted';
    final isRejected = status == 'rejected';
    final isCanceled = status == 'canceled';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('พบผู้ดูแล', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _kv('ชื่อผู้ใช้', identifier.isEmpty ? '-' : identifier),
          _kv('ชื่อ-นามสกุล', fullName.isEmpty ? '-' : fullName),
          _kv('เบอร์โทร', phone.isEmpty ? '-' : phone),
          if (status.isNotEmpty) ...[
            const SizedBox(height: 6),
            _kv('สถานะ', _statusText(status)),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (isPending || isAccepted) ? null : onSendRequest,
              icon: const Icon(Icons.send),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('ส่งคำขอเป็นผู้ดูแล'),
              ),
            ),
          ),
          if (isPending) ...[
            const SizedBox(height: 8),
            const Text(
              'รอผู้ดูแลกดยอมรับ',
              style: TextStyle(color: Colors.black54),
            ),
          ],
          if (isRejected) ...[
            const SizedBox(height: 8),
            const Text(
              'ผู้ดูแลปฏิเสธแล้ว (สามารถส่งคำขอใหม่ได้)',
              style: TextStyle(color: Colors.black54),
            ),
          ],
          if (isCanceled) ...[
            const SizedBox(height: 8),
            const Text(
              'คุณยกเลิกคำขอแล้ว (สามารถส่งใหม่ได้)',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  static String _statusText(String status) {
    switch (status) {
      case 'pending':
        return 'รอการยอมรับ';
      case 'accepted':
        return 'ยอมรับแล้ว';
      case 'rejected':
        return 'ปฏิเสธ';
      case 'canceled':
        return 'ยกเลิก';
      default:
        return status;
    }
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 92, child: Text(k, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _PendingRequestTile extends StatelessWidget {
  const _PendingRequestTile({
    required this.caregiverUid,
    required this.onCancel,
  });

  final String caregiverUid;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return FutureBuilder<DocumentSnapshot>(
      future: db.collection('users').doc(caregiverUid).get(),
      builder: (context, snap) {
        final data = (snap.data?.data() as Map<String, dynamic>?) ?? {};
        final identifier = (data['identifier'] ?? caregiverUid).toString();
        final fullName = (data['fullName'] ?? '').toString();

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
                    Text(
                      fullName.isEmpty ? identifier : fullName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text('ชื่อผู้ใช้: $identifier', style: const TextStyle(color: Colors.black54)),
                    const Text('สถานะ: รอการยอมรับ', style: TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              TextButton(
                onPressed: onCancel,
                child: const Text('ยกเลิก'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CaregiverTile extends StatelessWidget {
  const _CaregiverTile({
    required this.caregiverUid,
    required this.onRemove,
  });

  final String caregiverUid;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return FutureBuilder<DocumentSnapshot>(
      future: db.collection('users').doc(caregiverUid).get(),
      builder: (context, snap) {
        final data = (snap.data?.data() as Map<String, dynamic>?) ?? {};
        final identifier = (data['identifier'] ?? caregiverUid).toString();
        final fullName = (data['fullName'] ?? '').toString();
        final phone = (data['phone'] ?? '').toString();

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
                    Text(
                      fullName.isEmpty ? identifier : fullName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text('ชื่อผู้ใช้: $identifier', style: const TextStyle(color: Colors.black54)),
                    if (phone.isNotEmpty)
                      Text('โทร: $phone', style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'ลบผู้ดูแล',
              ),
            ],
          ),
        );
      },
    );
  }
}
