import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'theme/app_colors.dart';

import 'screens/home_caregiver_screen.dart';
import 'screens/home_elder_screen.dart';
import 'screens/role_select_screen.dart';

class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _AppLoadingScreen(message: 'กำลังตรวจสอบการเข้าสู่ระบบ...');
        }

        final user = authSnap.data;

        if (user == null) {
          return const RoleSelectScreen();
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (_, snap) {
            if (!snap.hasData || !snap.data!.exists) {
              return const _AppLoadingScreen(message: 'กำลังเชื่อมต่อข้อมูลของคุณ...');
            }

            final data = snap.data!.data() as Map<String, dynamic>;
            final role = data['role'];

            if (role == 'elder') {
              return const HomeElderScreen();
            }

            if (role == 'caregiver') {
              return const HomeCaregiverScreen();
            }

            return const RoleSelectScreen();
          },
        );
      },
    );
  }
}

class _AppLoadingScreen extends StatefulWidget {
  final String message;

  const _AppLoadingScreen({required this.message});

  @override
  State<_AppLoadingScreen> createState() => _AppLoadingScreenState();
}

class _AppLoadingScreenState extends State<_AppLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF2F6E6A);

    return Scaffold(
      backgroundColor: AppColors.card,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: Tween<double>(begin: 0.35, end: 1.0).animate(
                  CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: brandColor.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.2,
                      valueColor: AlwaysStoppedAnimation<Color>(brandColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'โปรดรอสักครู่เพื่อให้ข้อมูลพร้อมใช้งาน',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 23,
                  color: AppColors.subtleText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
