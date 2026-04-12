import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

import '../constants/family_relationships.dart';

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
  String? _relationshipToElder;
  String? _relationshipToCaregiver;

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
        _relationshipToElder = (data['relationshipToElder'] ?? '').toString();
        _relationshipToCaregiver = (data['relationshipToCaregiver'] ?? '').toString();
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
        if ((_role ?? '') == 'caregiver') 'relationshipToElder': (_relationshipToElder ?? '').trim(),
        if ((_role ?? '') == 'elder') 'relationshipToCaregiver': (_relationshipToCaregiver ?? '').trim(),
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
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),

              if ((_identifier ?? '').isNotEmpty) ...[
                _ReadOnlyTile(label: 'ชื่อผู้ใช้', value: _identifier!),
                const SizedBox(height: 12),
              ],
              if ((_role ?? '').isNotEmpty) ...[
                _ReadOnlyTile(label: 'บทบาท', value: _role!),
                const SizedBox(height: 12),
              ],
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
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
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
              const SizedBox(height: 16),

              if ((_role ?? '') == 'caregiver') ...[
                DropdownButtonFormField<String>(
                  value: (_relationshipToElder ?? '').isEmpty ? null : _relationshipToElder,
                  items: caregiverRelationshipOptions
                      .map(
                        (relationship) => DropdownMenuItem<String>(
                          value: relationship,
                          child: Text(relationship),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _relationshipToElder = value);
                  },
                  decoration: _dec('ความสัมพันธ์กับผู้สูงอายุ'),
                  validator: (value) {
                    if ((_role ?? '') == 'caregiver' && (value == null || value.isEmpty)) {
                      return 'กรุณาเลือกความสัมพันธ์';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
              ] else if ((_role ?? '') == 'elder') ...[
                DropdownButtonFormField<String>(
                  value: (_relationshipToCaregiver ?? '').isEmpty ? null : _relationshipToCaregiver,
                  items: caregiverRelationshipOptions
                      .map(
                        (relationship) => DropdownMenuItem<String>(
                          value: relationship,
                          child: Text(relationship),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _relationshipToCaregiver = value);
                  },
                  decoration: _dec('ความสัมพันธ์กับผู้ดูแล'),
                  validator: (value) {
                    if ((_role ?? '') == 'elder' && (value == null || value.isEmpty)) {
                      return 'กรุณาเลือกความสัมพันธ์';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
              ] else
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
                      style: const TextStyle(fontSize: 26),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.text),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.text)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
