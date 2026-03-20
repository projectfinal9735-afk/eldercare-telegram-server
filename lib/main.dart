import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'root.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ โปรเจกต์นี้ตั้งใจรองรับ Android เป็นหลัก
  // ถ้ารันบน Windows/macOS/Linux จะไม่ init Firebase เพื่อเลี่ยงปัญหา platform channel (ค้าง/Not Responding)
  final isAndroid = !kIsWeb && Platform.isAndroid;

  if (isAndroid) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const MyApp());
  } else {
    runApp(const AndroidOnlyApp());
  }
}

class AndroidOnlyApp extends StatelessWidget {
  const AndroidOnlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Elder Care',
      theme: buildAppTheme(),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'แอปนี้รองรับการใช้งานบน Android เท่านั้น\n'
              'กรุณารันบน Android Emulator หรือโทรศัพท์ Android',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      title: 'Elder Care',
      home: const Root(),
    );
  }
}
