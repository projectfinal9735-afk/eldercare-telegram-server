import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'edit_profile_screen.dart';

/// หน้าดูข้อมูลผู้ใช้ที่สมัครไว้ + ปุ่มแก้ไข (มี dialog ยืนยัน)
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmEdit(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการแก้ไข'),
        content: const Text('ต้องการแก้ไขข้อมูลส่วนตัวใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const Scaffold(
          appBar: _EditProfileAppBar(),
          body: EditProfileScreen(popOnSave: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('กรุณาเข้าสู่ระบบก่อน'));
    }

    final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: doc.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || !snap.data!.exists) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('ไม่พบข้อมูลผู้ใช้', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _confirmEdit(context),
                    icon: const Icon(Icons.edit),
                    label: const Text('สร้าง/แก้ไขข้อมูล'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snap.data!.data() as Map<String, dynamic>;
        final identifier = (data['identifier'] ?? '').toString();
        final fullName = (data['fullName'] ?? '').toString();
        final phone = (data['phone'] ?? '').toString();
        final role = (data['role'] ?? '').toString();

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'ข้อมูลผู้ใช้',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              _InfoCard(
                title: 'ชื่อผู้ใช้',
                value: identifier.isEmpty ? '-' : identifier,
                icon: Icons.person,
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'ชื่อ-นามสกุล',
                value: fullName.isEmpty ? '-' : fullName,
                icon: Icons.badge,
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'เบอร์โทรศัพท์',
                value: phone.isEmpty ? '-' : phone,
                icon: Icons.phone,
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'บทบาท',
                value: role.isEmpty ? '-' : role,
                icon: Icons.verified_user,
              ),

              const SizedBox(height: 18),

              SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color.fromARGB(255, 239, 150, 91), // ✅ สีปุ่ม
      foregroundColor: Colors.white,     // ✅ สีไอคอน + ตัวหนังสือ
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
    onPressed: () => _confirmEdit(context),
    icon: const Icon(Icons.edit),
    label: const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Text(
        'แก้ไขข้อมูล',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  ),
),
            ],
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProfileAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _EditProfileAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('แก้ไขข้อมูลส่วนตัว'),
    );
  }
}
