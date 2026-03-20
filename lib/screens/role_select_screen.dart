import 'package:flutter/material.dart';
import '../widgets/primary_button.dart';
import 'login_elder_screen.dart';
import 'login_caregiver_screen.dart';
import 'package:elder_care_app/theme/app_colors.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

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
                    'เดินทาง\nสบาย',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 56,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 52),
                  PrimaryButton(
                    text: 'ผู้สูงอายุ',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginElderScreen()),
                    ),
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    text: 'ผู้ดูแล',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginCaregiverScreen()),
                    ),
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    text: 'วิธีใช้งาน',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('เดี๋ยวทำหน้าวิธีใช้งานต่อได้')),
                      );
                    },
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
