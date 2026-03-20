import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// หน้าแก้ไขข้อมูลผู้ใช้ (อ่านค่าจาก Firestore และบันทึกกลับไปที่ users/{uid})
///
/// ใช้ได้ทั้งแบบ Navigator.push ไปหน้าใหม่ หรือวางใน IndexedStack ก็ได้
/// - ถ้า [popOnSave] = true จะ pop กลับอัตโนมัติเมื่อบันทึกสำเร็จ
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.popOnSave = false});

  final bool popOnSave;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullName = TextEditingController();
  final _phone = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String? _identifier;
  String? _role;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        _identifier = (data['identifier'] ?? '').toString();
        _role = (data['role'] ?? '').toString();
        _fullName.text = (data['fullName'] ?? '').toString();
        _phone.text = (data['phone'] ?? '').toString();
      }
    } catch (_) {
      // ปล่อยให้ UI แสดงแบบว่าง ๆ แล้วให้ผู้ใช้กรอกใหม่ได้
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อน')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fullName': _fullName.text.trim(),
        'phone': _phone.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกข้อมูลเรียบร้อย')),
      );

      if (widget.popOnSave) {
        Navigator.pop(context);
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'บันทึกไม่สำเร็จ')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'แก้ไขข้อมูลส่วนตัว',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),

              if ((_identifier ?? '').isNotEmpty)
                _ReadOnlyTile(label: 'ชื่อผู้ใช้', value: _identifier!),
              if ((_role ?? '').isNotEmpty)
                _ReadOnlyTile(label: 'บทบาท', value: _role!),
              if ((_identifier ?? '').isNotEmpty || (_role ?? '').isNotEmpty)
                const SizedBox(height: 16),

              TextFormField(
                controller: _fullName,
                decoration: _dec('ชื่อ-นามสกุล'),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'กรุณากรอกชื่อ-นามสกุล';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: _dec('เบอร์โทรศัพท์'),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'กรุณากรอกเบอร์โทรศัพท์';
                  if (!RegExp(r'^\d{10}$').hasMatch(t)) {
                    return 'เบอร์โทรต้องเป็นตัวเลข 10 หลัก';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      _saving ? 'กำลังบันทึก...' : 'บันทึก',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyTile extends StatelessWidget {
  const _ReadOnlyTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color.fromARGB(220, 0, 0, 0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color.fromARGB(220, 0, 0, 0))),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
