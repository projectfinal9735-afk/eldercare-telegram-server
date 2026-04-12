import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/family_relationships.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';

class SignupCaregiverScreen extends StatefulWidget {
  const SignupCaregiverScreen({super.key});

  @override
  State<SignupCaregiverScreen> createState() => _SignupCaregiverScreenState();
}

class _SignupCaregiverScreenState extends State<SignupCaregiverScreen> {
  final _identifier = TextEditingController();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  String? _relationshipToElder;

  bool _loading = false;
  bool _hidePw = true;
  bool _hideConfirmPw = true;

  @override
  void dispose() {
    _identifier.dispose();
    _fullName.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final identifier = _identifier.text.trim();
    final fullName = _fullName.text.trim();
    final phone = _phone.text.trim();
    final password = _password.text;
    final confirm = _confirmPassword.text;
    final relationshipToElder = _relationshipToElder;

    if (identifier.isEmpty || fullName.isEmpty || phone.isEmpty || password.isEmpty || confirm.isEmpty || relationshipToElder == null || relationshipToElder.isEmpty) {
      _snack('กรุณากรอกข้อมูลให้ครบ');
      return;
    }
    if (password.length < 6 || password.length > 8) {
      _snack('รหัสผ่านต้อง 6-8 ตัว');
      return;
    }
    if (password != confirm) {
      _snack('รหัสผ่านไม่ตรงกัน');
      return;
    }

    try {
      setState(() => _loading = true);
      await AuthService.instance.registerCaregiver(
        identifier: identifier,
        password: password,
        fullName: fullName,
        phone: phone,
        relationshipToElder: relationshipToElder,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      _snack(e.toString().replaceAll('Exception:', '').trim());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _decoration({required String hint, required IconData icon, Widget? suffix}) {
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
      appBar: AppBar(title: const Text('สมัครสมาชิกผู้ดูแล')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.health_and_safety, size: 56, color: AppColors.primary),
                      const SizedBox(height: 16),
                      const Text(
                        'สมัครสมาชิกผู้ดูแล',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'ออกแบบให้ปุ่มใหญ่ ตัวหนังสือชัด และกรอกข้อมูลได้ง่าย',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, color: AppColors.subtleText, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _identifier,
                        enabled: !_loading,
                        style: const TextStyle(fontSize: 24),
                        decoration: _decoration(hint: 'ชื่อผู้ใช้', icon: Icons.person),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _fullName,
                        enabled: !_loading,
                        style: const TextStyle(fontSize: 24),
                        decoration: _decoration(hint: 'ชื่อ-นามสกุล', icon: Icons.badge),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _phone,
                        enabled: !_loading,
                        style: const TextStyle(fontSize: 24),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: _decoration(hint: 'เบอร์โทรศัพท์', icon: Icons.phone),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _relationshipToElder,
                        items: caregiverRelationshipOptions
                            .map(
                              (relationship) => DropdownMenuItem<String>(
                                value: relationship,
                                child: Text(relationship, style: const TextStyle(fontSize: 24)),
                              ),
                            )
                            .toList(),
                        onChanged: _loading ? null : (value) => setState(() => _relationshipToElder = value),
                        decoration: _decoration(hint: 'คุณเป็นใครของผู้สูงอายุ', icon: Icons.family_restroom),
                        dropdownColor: AppColors.field,
                        style: const TextStyle(fontSize: 24, color: AppColors.text),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        enabled: !_loading,
                        style: const TextStyle(fontSize: 24),
                        obscureText: _hidePw,
                        inputFormatters: [LengthLimitingTextInputFormatter(8)],
                        decoration: _decoration(
                          hint: 'รหัสผ่าน (6-8 ตัว)',
                          icon: Icons.lock,
                          suffix: IconButton(
                            icon: Icon(_hidePw ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _hidePw = !_hidePw),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _confirmPassword,
                        enabled: !_loading,
                        style: const TextStyle(fontSize: 24),
                        obscureText: _hideConfirmPw,
                        inputFormatters: [LengthLimitingTextInputFormatter(8)],
                        decoration: _decoration(
                          hint: 'ยืนยันรหัสผ่าน',
                          icon: Icons.lock_outline,
                          suffix: IconButton(
                            icon: Icon(_hideConfirmPw ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _hideConfirmPw = !_hideConfirmPw),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      PrimaryButton(
                        text: _loading ? 'กำลังสมัคร...' : 'สมัครสมาชิก',
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
    );
  }
}
