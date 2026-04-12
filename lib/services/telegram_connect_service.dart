import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class TelegramConnectService {
  TelegramConnectService._();

  // LINE Official Account basic ID.
  static const String officialAccountId = String.fromEnvironment(
    'LINE_OFFICIAL_ACCOUNT_ID',
    defaultValue: '@912autab',
  );

  // Backward-compatible alias from the previous Telegram-based implementation.
  static String get botUsername => officialAccountId;

  static String? buildLinkMessage() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return 'LINK caregiver_$uid';
  }

  static Uri? buildConnectUri() {
    final message = buildLinkMessage();
    if (message == null) return null;
    final encodedId = Uri.encodeComponent(officialAccountId);
    final encodedMessage = Uri.encodeComponent(message);
    return Uri.parse('https://line.me/R/oaMessage/$encodedId/?$encodedMessage');
  }

  static Future<bool> openConnectBot() async {
    final uri = buildConnectUri();
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
