class UserModel {
  final String uid;
  final String role;
  final String identifier;
  final String fullName;
  final String phone;
  final String relationshipToElder;
  final String relationshipToCaregiver;
  final List<String> elderIds;
  final List<String> caregiverIds;
  final String lineUserId;
  final bool lineConnected;

  const UserModel({
    required this.uid,
    required this.role,
    required this.identifier,
    required this.fullName,
    required this.phone,
    this.relationshipToElder = '',
    this.relationshipToCaregiver = '',
    this.elderIds = const [],
    this.caregiverIds = const [],
    this.lineUserId = '',
    this.lineConnected = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: (map['uid'] ?? '').toString(),
      role: (map['role'] ?? '').toString(),
      identifier: (map['identifier'] ?? '').toString(),
      fullName: (map['fullName'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      relationshipToElder: (map['relationshipToElder'] ?? '').toString(),
      relationshipToCaregiver: (map['relationshipToCaregiver'] ?? '').toString(),
      elderIds: (map['elderIds'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      caregiverIds: (map['caregiverIds'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      lineUserId: (map['lineUserId'] ?? '').toString(),
      lineConnected: (map['lineConnected'] ?? false) == true,
    );
  }
}
