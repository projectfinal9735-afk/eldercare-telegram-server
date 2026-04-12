import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import 'login_caregiver_screen.dart';
import 'login_elder_screen.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 94,
                        height: 94,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Icon(Icons.favorite, size: 48, color: AppColors.primary),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'เดินทางสบาย',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'เลือกประเภทผู้ใช้งาน เพื่อเข้าสู่ระบบได้ง่ายและชัดเจน',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, color: AppColors.subtleText, height: 1.5),
                      ),
                      const SizedBox(height: 28),
                      PrimaryButton(
                        text: 'เข้าใช้งานสำหรับผู้สูงอายุ',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginElderScreen()),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(72),
                          side: const BorderSide(color: AppColors.primary, width: 1.8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginCaregiverScreen()),
                        ),
                        child: const Text(
                          'เข้าใช้งานสำหรับคนใกล้ชิด',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                        ),
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
