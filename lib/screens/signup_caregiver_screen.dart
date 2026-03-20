import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../services/auth_service.dart';

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

    if (identifier.isEmpty ||
        fullName.isEmpty ||
        phone.isEmpty ||
        password.isEmpty ||
        confirm.isEmpty) {
      _snack('กรุณากรอกข้อมูลให้ครบ');
      return;
    }

    if (password.length < 6 || password.length > 8) {
      _snack('รหัสผ่านต้อง 6–8 ตัว');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.accent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 28),

                  /// ===== หัวข้อ =====
                  const Center(
                    child: Text(
                      'ผู้ดูแล',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  TextField(
                    controller: _identifier,
                    enabled: !_loading,
                    decoration: _decoration(
                      hint: 'ชื่อผู้ใช้',
                      icon: Icons.person,
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _fullName,
                    enabled: !_loading,
                    decoration: _decoration(
                      hint: 'ชื่อ-นามสกุล',
                      icon: Icons.badge,
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _phone,
                    enabled: !_loading,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: _decoration(
                      hint: 'เบอร์โทรศัพท์',
                      icon: Icons.phone,
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _password,
                    enabled: !_loading,
                    obscureText: _hidePw,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: _decoration(
                      hint: 'รหัสผ่าน (6–8 ตัว)',
                      icon: Icons.lock,
                      suffix: IconButton(
                        icon: Icon(
                          _hidePw ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _hidePw = !_hidePw),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _confirmPassword,
                    enabled: !_loading,
                    obscureText: _hideConfirmPw,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: _decoration(
                      hint: 'ยืนยันรหัสผ่าน',
                      icon: Icons.lock_outline,
                      suffix: IconButton(
                        icon: Icon(
                          _hideConfirmPw ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _hideConfirmPw = !_hideConfirmPw),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  PrimaryButton(
                    text: _loading ? 'กำลังสมัคร...' : 'สมัครสมาชิก',
                    onPressed: _loading ? null : _signup,
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
