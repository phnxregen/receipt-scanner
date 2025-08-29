import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';

/// Simple helper to open the TurboScan app.
///
/// Notes:
/// - On Android, attempts to launch by package name (com.piksoft.turboscan).
/// - If not installed, falls back to opening the store listing.
/// - On iOS, tries known URL schemes if provided via vendor docs (placeholder here),
///   otherwise opens the App Store listing.
class TurboScanService {
  static const String _androidPackage = 'com.piksoft.turboscan';
  static const String _androidPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.piksoft.turboscan';

  // If TurboScan provides a custom URL scheme, add it here.
  // Replace with the correct scheme/action from the vendor instructions.
  static const String _iosUrlScheme = 'turboscan://'; // TODO: confirm via API doc
  static const String _iosAppStoreUrl =
      'https://apps.apple.com/app/id342548956'; // TurboScan app id (to verify)

  /// Launches TurboScan if available. Returns true if an attempt to open was made.
  static Future<bool> openTurboScan() async {
    if (Platform.isAndroid) {
      try {
        final intent = AndroidIntent(
          action: 'action_view',
          package: _androidPackage,
        );
        await intent.launch();
        return true;
      } catch (_) {
        // Fallback to Play Store listing
        final uri = Uri.parse(_androidPlayStoreUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return false;
        }
      }
      return false;
    }

    if (Platform.isIOS) {
      // Try custom scheme if available
      final scheme = Uri.parse(_iosUrlScheme);
      if (await canLaunchUrl(scheme)) {
        await launchUrl(scheme, mode: LaunchMode.externalApplication);
        return true;
      }
      // Fallback to App Store
      final uri = Uri.parse(_iosAppStoreUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return false;
      }
      return false;
    }

    if (kIsWeb) {
      // Not supported on web; no-op
      return false;
    }

    // Other platforms
    return false;
  }
}

