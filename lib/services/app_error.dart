import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppError {
  static String message(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'ชื่อผู้ใช้ไม่ถูกต้อง';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง';
        case 'email-already-in-use':
          return 'ชื่อผู้ใช้นี้ถูกใช้งานแล้ว';
        case 'weak-password':
          return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
        case 'too-many-requests':
          return 'พยายามหลายครั้งเกินไป กรุณาลองใหม่ภายหลัง';
        case 'network-request-failed':
          return 'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้';
        case 'requires-recent-login':
          return 'กรุณาเข้าสู่ระบบใหม่ แล้วลองเปลี่ยนรหัสผ่านอีกครั้ง';
      }
      return error.message ?? 'เกิดข้อผิดพลาดจากการเข้าสู่ระบบ';
    }

    if (error is FirebaseException) {
      return error.message ?? 'เกิดข้อผิดพลาดจากฐานข้อมูล';
    }

    return error.toString().replaceAll('Exception:', '').trim();
  }
}
