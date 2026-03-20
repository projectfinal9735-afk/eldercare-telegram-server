import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../services/auth_service.dart';

class SignupElderScreen extends StatefulWidget {
  const SignupElderScreen({super.key});

  @override
  State<SignupElderScreen> createState() => _SignupElderScreenState();
}

class _SignupElderScreenState extends State<SignupElderScreen> {
  final _formKey = GlobalKey<FormState>();

  final _identifierController = TextEditingController(); // ชื่อผู้ใช้
  final _fullNameController = TextEditingController();   // ชื่อ-นามสกุล
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

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

    try {
      setState(() => _loading = true);

      await AuthService.instance.registerElder(
        identifier: identifier,
        password: password,
        fullName: fullName,
        phone: phone,
      );

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'สมัครสมาชิกไม่สำเร็จ')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix}) {
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    const Text(
                      'ผู้สูงอายุ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 32),

                    TextFormField(
                      controller: _identifierController,
                      decoration: _decoration('ชื่อผู้ใช้', Icons.person),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'กรุณากรอกชื่อผู้ใช้' : null,
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _fullNameController,
                      decoration: _decoration('ชื่อ-นามสกุล', Icons.badge),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'กรุณากรอกชื่อ-นามสกุล' : null,
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: _decoration('เบอร์โทรศัพท์', Icons.phone),
                      validator: (v) =>
                          v == null || v.length != 10 ? 'เบอร์โทรต้องครบ 10 หลัก' : null,
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _hidePw,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(8),
                      ],
                      decoration: _decoration(
                        'รหัสผ่าน (6–8 ตัว)',
                        Icons.lock,
                        suffix: IconButton(
                          icon: Icon(
                            _hidePw ? Icons.visibility_off : Icons.visibility,
                            color: Colors.red,
                          ),
                          onPressed: () =>
                              setState(() => _hidePw = !_hidePw),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'กรุณากรอกรหัสผ่าน';
                        if (v.length < 6) return 'อย่างน้อย 6 ตัว';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _hideConfirmPw,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(8),
                      ],
                      decoration: _decoration(
                        'ยืนยันรหัสผ่าน',
                        Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            _hideConfirmPw
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.red,
                          ),
                          onPressed: () =>
                              setState(() => _hideConfirmPw = !_hideConfirmPw),
                        ),
                      ),
                      validator: (v) =>
                          v != _passwordController.text ? 'รหัสผ่านไม่ตรงกัน' : null,
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
    );
  }
}
