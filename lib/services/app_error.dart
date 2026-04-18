import 'dart:async';
import 'dart:io';

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
          return 'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาตรวจสอบสัญญาณแล้วลองใหม่';
        case 'requires-recent-login':
          return 'กรุณาเข้าสู่ระบบใหม่ แล้วลองเปลี่ยนรหัสผ่านอีกครั้ง';
        case 'not-authenticated':
          return 'กรุณาเข้าสู่ระบบก่อน';
      }
      return error.message ?? 'เกิดข้อผิดพลาดจากการเข้าสู่ระบบ';
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'ไม่มีสิทธิ์เข้าถึงข้อมูลนี้';
        case 'unavailable':
          return 'เซิร์ฟเวอร์ฐานข้อมูลไม่พร้อมใช้งานชั่วคราว กรุณาลองใหม่';
        case 'deadline-exceeded':
          return 'การเชื่อมต่อฐานข้อมูลใช้เวลานานเกินไป กรุณาลองใหม่';
        case 'not-found':
          return 'ไม่พบข้อมูลที่ต้องการ';
        case 'cancelled':
          return 'การทำรายการถูกยกเลิก';
      }
      return error.message ?? 'เกิดข้อผิดพลาดจากฐานข้อมูล';
    }

    if (error is TimeoutException) {
      return 'ระบบตอบสนองช้ากว่าปกติ กรุณาลองใหม่';
    }

    if (error is SocketException) {
      return 'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาตรวจสอบสัญญาณแล้วลองใหม่';
    }

    final raw = error.toString().replaceAll('Exception:', '').trim();
    final lower = raw.toLowerCase();

    if (lower.contains('denied forever')) {
      return 'ปิดสิทธิ์ตำแหน่งแบบถาวร กรุณาไปที่การตั้งค่าแล้วอนุญาตตำแหน่ง';
    }
    if (lower.contains('permission') || raw.contains('อนุญาต')) {
      return raw;
    }
    if (lower.contains('socketexception') || lower.contains('failed host lookup')) {
      return 'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาตรวจสอบสัญญาณแล้วลองใหม่';
    }
    if (lower.contains('timeout') || raw.contains('ใช้เวลานานเกินไป')) {
      return 'ระบบตอบสนองช้ากว่าปกติ กรุณาลองใหม่';
    }
    if (raw.contains('ไม่พบข้อมูล') || raw.contains('ไม่พบเส้นทาง')) {
      return raw;
    }

    return raw.isEmpty ? 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ' : raw;
  }
}
