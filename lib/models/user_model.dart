class UserModel {
  final String uid;
  final String role;
  final String identifier;
  final String fullName;
  final String phone;
  final List<String> elderIds;
  final List<String> caregiverIds;
  final String telegramChatId;
  final bool telegramConnected;

  const UserModel({
    required this.uid,
    required this.role,
    required this.identifier,
    required this.fullName,
    required this.phone,
    this.elderIds = const [],
    this.caregiverIds = const [],
    this.telegramChatId = '',
    this.telegramConnected = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: (map['uid'] ?? '').toString(),
      role: (map['role'] ?? '').toString(),
      identifier: (map['identifier'] ?? '').toString(),
      fullName: (map['fullName'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      elderIds: (map['elderIds'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      caregiverIds: (map['caregiverIds'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      telegramChatId: (map['telegramChatId'] ?? '').toString(),
      telegramConnected: (map['telegramConnected'] ?? false) == true,
    );
  }
}
