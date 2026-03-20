import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPw = TextEditingController();
  final _newPw = TextEditingController();
  final _confirmPw = TextEditingController();
  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPw.dispose();
    _newPw.dispose();
    _confirmPw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_currentPw.text.isEmpty) {
      _showSnack('กรุณากรอกรหัสผ่านเดิม');
      return;
    }
    if (_newPw.text.length < 6) {
      _showSnack('รหัสผ่านใหม่อย่างน้อย 6 ตัว');
      return;
    }
    if (_newPw.text != _confirmPw.text) {
      _showSnack('ยืนยันรหัสผ่านใหม่ไม่ตรงกัน');
      return;
    }
    if (_currentPw.text == _newPw.text) {
      _showSnack('รหัสผ่านใหม่ต้องไม่ซ้ำรหัสผ่านเดิม');
      return;
    }

    try {
      setState(() => _loading = true);
      await AuthService.instance.changePassword(
        currentPassword: _currentPw.text,
        newPassword: _newPw.text,
      );
      if (!mounted) return;
      _showSnack('เปลี่ยนรหัสผ่านสำเร็จ');
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
      appBar: AppBar(title: const Text('เปลี่ยนรหัสผ่าน')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _currentPw,
                obscureText: _obscureCurrent,
                enabled: !_loading,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่านเดิม',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newPw,
                obscureText: _obscureNew,
                enabled: !_loading,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่านใหม่',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPw,
                obscureText: _obscureConfirm,
                enabled: !_loading,
                decoration: InputDecoration(
                  labelText: 'ยืนยันรหัสผ่านใหม่',
                  prefixIcon: const Icon(Icons.lock_reset),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(_loading ? 'กำลังบันทึก...' : 'บันทึกรหัสผ่านใหม่'),
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
