import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_error.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _normalizeIdentifier(String identifier) {
    return identifier.trim().replaceAll(RegExp(r'\s+'), '');
  }

  /// แปลง identifier (ชื่อผู้ใช้ / เบอร์) -> email ปลอม
  String _toEmail(String identifier) {
    final cleaned = _normalizeIdentifier(identifier);
    return '$cleaned@eldercare.app';
  }

  String mapAuthError(Object error) {
    if (error is FirebaseAuthException &&
        (error.code == 'profile-missing' || error.code == 'wrong-role' || error.code == 'not-authenticated')) {
      return error.message ?? 'ไม่สามารถทำรายการได้';
    }
    return AppError.message(error);
  }

  Future<void> registerCaregiver({
    required String identifier,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final email = _toEmail(identifier);

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _db.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'role': 'caregiver',
      'identifier': _normalizeIdentifier(identifier),
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      'isSearchable': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> registerElder({
    required String identifier,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final email = _toEmail(identifier);

    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _db.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'role': 'elder',
      'identifier': _normalizeIdentifier(identifier),
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> signInWithIdentifierEnsureRole({
    required String identifier,
    required String password,
    required String expectedRole,
  }) async {
    final email = _toEmail(identifier);

    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = cred.user!.uid;
    final snap = await _db.collection('users').doc(uid).get();

    if (!snap.exists) {
      throw FirebaseAuthException(
        code: 'profile-missing',
        message: 'ไม่พบข้อมูลผู้ใช้',
      );
    }

    final role = snap.data()!['role'];
    if (role != expectedRole) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'wrong-role',
        message: 'บทบาทไม่ถูกต้อง',
      );
    }
  }

  Future<void> sendPasswordResetByIdentifier({
    required String identifier,
  }) async {
    final email = _toEmail(identifier);
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'กรุณาเข้าสู่ระบบก่อน',
      );
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'ไม่พบอีเมลผู้ใช้',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
    await _db.collection('users').doc(user.uid).set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getMyProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snap = await _db.collection('users').doc(user.uid).get();
    return snap.data();
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'กรุณาเข้าสู่ระบบก่อน',
      );
    }

    await _db.collection('users').doc(user.uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> signOut() => _auth.signOut();
}
