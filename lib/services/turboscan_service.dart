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

  // Known/likely TurboScan URL schemes (based on vendor docs / common patterns).
  // We'll attempt these in order on iOS.
  static const List<String> _iosUrlSchemes = <String>[
    'turboscan://',
    // Some builds may expose a specific action route
    'turboscan://scan',
    // Alternate short scheme seen in some integrations
    'tscan://',
    // Potential variant bundle schemes
    'turboscanpro://',
    'turboscanfree://',
  ];
  // Prefer itms-apps to avoid opening Safari when possible
  static const String _iosAppStoreUrl =
      'itms-apps://apps.apple.com/app/id342548956'; // TurboScan app id (to verify)

  /// Launches TurboScan if available. Returns true if an attempt to open was made.
  static Future<bool> openTurboScan() async {
    if (Platform.isAndroid) {
      try {
        // Try to launch the main activity of TurboScan.
        // Use ACTION_MAIN with CATEGORY_LAUNCHER scoped to the package.
        final intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          category: 'android.intent.category.LAUNCHER',
          package: _androidPackage,
        );
        await intent.launch();
        return true;
      } catch (_) {
        // Fallback to Play Store listing
        final uri = Uri.parse(_androidPlayStoreUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          // We opened the store; treat as a handled action.
          return true;
        }
      }
      return false;
    }

    if (Platform.isIOS) {
      // Try multiple candidate URL schemes without relying solely on canLaunch.
      for (final s in _iosUrlSchemes) {
        final uri = Uri.parse(s);
        try {
          // Try launching directly (canLaunchUrl can be restrictive on iOS)
          final ok = await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
          if (ok) return true;
        } catch (_) {
          // try next candidate
        }
      }

      // Fallback: open App Store listing for TurboScan
      try {
        final store = Uri.parse(_iosAppStoreUrl);
        final ok = await launchUrl(store, mode: LaunchMode.externalApplication);
        if (ok) return true;
      } catch (_) {
        // ignore
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
