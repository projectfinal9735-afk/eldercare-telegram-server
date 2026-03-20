import 'package:elder_care_app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../widgets/primary_button.dart';
import 'forgot_password_screen.dart';
import 'signup_elder_screen.dart';

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
      backgroundColor: AppColors.accent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'ผู้สูงอายุ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _idController,
                    enabled: !_loading,
                    decoration: const InputDecoration(
                      hintText: 'ชื่อผู้ใช้ / เบอร์โทรศัพท์',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pwController,
                    enabled: !_loading,
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
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'ลืมรหัสผ่าน',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Text(
                            'หากยังไม่มีบัญชี  ',
                            style: TextStyle(color: Colors.white70),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignupElderScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'สมัครสมาชิก',
                              style: TextStyle(
                                color: Color.fromARGB(200, 255, 255, 255),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
    );
  }
}
