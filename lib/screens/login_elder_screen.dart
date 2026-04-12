import 'package:elder_care_app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../widgets/primary_button.dart';

class LoginElderScreen extends StatefulWidget {
  const LoginElderScreen({super.key});

  @override
  State<LoginElderScreen> createState() => _LoginElderScreenState();
}

class _LoginElderScreenState extends State<LoginElderScreen> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();

  bool _loading = false;
  bool _obscurePw = true;

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final identifier = _idController.text.trim();
    final password = _pwController.text;

    if (identifier.isEmpty || password.isEmpty) {
      _snack('กรุณากรอกข้อมูลให้ครบ');
      return;
    }

    try {
      setState(() => _loading = true);

      await AuthService.instance.signInWithIdentifierEnsureRole(
        identifier: identifier,
        password: password,
        expectedRole: 'elder',
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      _snack(AuthService.instance.mapAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เข้าสู่ระบบ')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.elderly, size: 58, color: AppColors.primary),
                      const SizedBox(height: 16),
                      const Text(
                        'ผู้สูงอายุ',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'กรอกชื่อผู้ใช้และรหัสผ่าน เพื่อเข้าใช้งาน',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 26, color: AppColors.subtleText),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _idController,
                        enabled: !_loading,
                        style: const TextStyle(fontSize: 26),
                        decoration: const InputDecoration(
                          hintText: 'ชื่อผู้ใช้',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _pwController,
                        enabled: !_loading,
                        style: const TextStyle(fontSize: 26),
                        obscureText: _obscurePw,
                        inputFormatters: [LengthLimitingTextInputFormatter(8)],
                        decoration: InputDecoration(
                          hintText: 'รหัสผ่าน',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePw ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscurePw = !_obscurePw),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        text: _loading ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบ',
                        onPressed: _loading ? null : _login,
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
