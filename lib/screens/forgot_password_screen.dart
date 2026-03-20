import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _identifierController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      _showSnack('กรุณากรอกชื่อผู้ใช้หรือเบอร์โทรศัพท์');
      return;
    }

    try {
      setState(() => _loading = true);
      await AuthService.instance.sendPasswordResetByIdentifier(
        identifier: identifier,
      );
      if (!mounted) return;
      _showSnack('ส่งลิงก์รีเซ็ตรหัสผ่านแล้ว กรุณาตรวจสอบอีเมลของบัญชีนี้');
      Navigator.pop(context);
    } catch (e) {
      _showSnack(AuthService.instance.mapAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ลืมรหัสผ่าน')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'กรอกชื่อผู้ใช้หรือเบอร์โทรศัพท์ที่ใช้สมัคร ระบบจะส่งลิงก์รีเซ็ตรหัสผ่านไปยังอีเมลของบัญชีนั้น',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _identifierController,
                enabled: !_loading,
                decoration: const InputDecoration(
                  labelText: 'ชื่อผู้ใช้ / เบอร์โทรศัพท์',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(_loading ? 'กำลังส่ง...' : 'ส่งลิงก์รีเซ็ตรหัสผ่าน'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
