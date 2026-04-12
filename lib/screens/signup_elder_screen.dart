import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/family_relationships.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';

class SignupElderScreen extends StatefulWidget {
  final bool managedByCaregiver;

  const SignupElderScreen({
    super.key,
    this.managedByCaregiver = false,
  });

  @override
  State<SignupElderScreen> createState() => _SignupElderScreenState();
}

class _SignupElderScreenState extends State<SignupElderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _relationshipToElder;
  bool _loading = false;
  bool _hidePw = true;
  bool _hideConfirmPw = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final identifier = _identifierController.text.trim();
    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final relationshipToElder = _relationshipToElder;

    if (widget.managedByCaregiver && (relationshipToElder == null || relationshipToElder.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกความสัมพันธ์กับผู้สูงอายุ')),
      );
      return;
    }

    try {
      setState(() => _loading = true);
      if (widget.managedByCaregiver) {
        await AuthService.instance.registerElderByCaregiver(
          identifier: identifier,
          password: password,
          fullName: fullName,
          phone: phone,
          relationshipToElder: relationshipToElder!,
        );
      } else {
        await AuthService.instance.registerElder(
          identifier: identifier,
          password: password,
          fullName: fullName,
          phone: phone,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.isEmpty ? 'สมัครไม่สำเร็จ' : message)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      fillColor: AppColors.field,
      prefixIcon: Icon(icon, size: 28),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สมัครสมาชิก')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          widget.managedByCaregiver ? Icons.person_add : Icons.elderly,
                          size: 56,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.managedByCaregiver ? 'เพิ่มผู้สูงอายุ' : 'สมัครสมาชิกผู้สูงอายุ',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.managedByCaregiver
                              ? 'กรอกข้อมูลให้ครบ เพื่อเพิ่มผู้สูงอายุเข้าสู่ระบบ'
                              : 'กรอกข้อมูลให้ครบ แล้วเริ่มใช้งานได้ทันที',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, color: AppColors.subtleText, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _identifierController,
                          style: const TextStyle(fontSize: 24),
                          decoration: _decoration(
                            widget.managedByCaregiver ? 'ชื่อผู้ใช้ผู้สูงอายุ' : 'ชื่อผู้ใช้',
                            Icons.person,
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'กรุณากรอกชื่อผู้ใช้' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _fullNameController,
                          style: const TextStyle(fontSize: 24),
                          decoration: _decoration('ชื่อ-นามสกุล', Icons.badge),
                          validator: (v) => v == null || v.trim().isEmpty ? 'กรุณากรอกชื่อ' : null,
                        ),
                        const SizedBox(height: 14),
                        if (widget.managedByCaregiver) ...[
                          DropdownButtonFormField<String>(
                            initialValue: _relationshipToElder,
                            items: caregiverRelationshipOptions
                                .where((relationship) => const ['พ่อ', 'แม่', 'ปู่', 'ย่า', 'ตา', 'ยาย'].contains(relationship))
                                .map(
                                  (relationship) => DropdownMenuItem<String>(
                                    value: relationship,
                                    child: Text(relationship, style: const TextStyle(fontSize: 24)),
                                  ),
                                )
                                .toList(),
                            onChanged: _loading ? null : (value) => setState(() => _relationshipToElder = value),
                            decoration: _decoration('ผู้สูงอายุท่านนี้เป็นใคร', Icons.family_restroom),
                            dropdownColor: AppColors.field,
                            style: const TextStyle(fontSize: 24, color: AppColors.text),
                            validator: (value) {
                              if (!widget.managedByCaregiver) return null;
                              if (value == null || value.isEmpty) return 'กรุณาเลือกความสัมพันธ์';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: _phoneController,
                          style: const TextStyle(fontSize: 24),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: _decoration('เบอร์โทร', Icons.phone),
                          validator: (v) => v == null || v.length != 10 ? 'เบอร์ไม่ครบ 10 หลัก' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          style: const TextStyle(fontSize: 24),
                          obscureText: _hidePw,
                          inputFormatters: [LengthLimitingTextInputFormatter(8)],
                          decoration: _decoration(
                            'รหัสผ่าน (6-8 ตัว)',
                            Icons.lock,
                            suffix: IconButton(
                              icon: Icon(_hidePw ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _hidePw = !_hidePw),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmPasswordController,
                          style: const TextStyle(fontSize: 24),
                          obscureText: _hideConfirmPw,
                          inputFormatters: [LengthLimitingTextInputFormatter(8)],
                          decoration: _decoration(
                            'ยืนยันรหัสผ่าน',
                            Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(_hideConfirmPw ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _hideConfirmPw = !_hideConfirmPw),
                            ),
                          ),
                          validator: (v) => v != _passwordController.text ? 'รหัสไม่ตรงกัน' : null,
                        ),
                        const SizedBox(height: 28),
                        PrimaryButton(
                          text: _loading
                              ? (widget.managedByCaregiver ? 'กำลังเพิ่ม...' : 'กำลังสมัคร...')
                              : (widget.managedByCaregiver ? 'เพิ่มผู้สูงอายุ' : 'สมัครสมาชิก'),
                          onPressed: _loading ? null : _signup,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
