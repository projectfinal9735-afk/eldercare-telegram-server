import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class TelegramConnectService {
  TelegramConnectService._();

  static const String botUsername = 'elder_care_alert_bot';

  static Uri? buildConnectUri() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    return Uri.parse(
      'https://t.me/$botUsername?start=caregiver_$uid',
    );
  }

  static Future<bool> openConnectBot() async {
    final uri = buildConnectUri();
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}