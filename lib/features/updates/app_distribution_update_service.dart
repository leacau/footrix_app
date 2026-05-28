import 'dart:async';

import 'package:firebase_app_distribution/firebase_app_distribution.dart'
    as app_distribution;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppDistributionUpdateService {
  static const _lastTesterPromptAtKey =
      'app_distribution_last_tester_prompt_at';
  static const _testerPromptCooldown = Duration(hours: 24);
  static bool _alreadyChecked = false;

  static void checkForTesterUpdateInBackground() {
    if (_alreadyChecked || kIsWeb || !kReleaseMode) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    _alreadyChecked = true;
    Timer(const Duration(seconds: 6), () async {
      try {
        final isTesterSignedIn = await app_distribution.isTesterSignedIn();
        if (isTesterSignedIn) {
          await app_distribution.updateIfNewReleaseAvailable();
          return;
        }

        if (await _canPromptTesterSignIn()) {
          await _markTesterPromptShown();
          await app_distribution.signInTester();
        }
      } catch (error) {
        debugPrint('App Distribution update check skipped: $error');
      }
    });
  }

  static Future<bool> _canPromptTesterSignIn() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPromptAt = prefs.getInt(_lastTesterPromptAtKey);
    if (lastPromptAt == null) return true;

    final lastPrompt = DateTime.fromMillisecondsSinceEpoch(lastPromptAt);
    return DateTime.now().difference(lastPrompt) > _testerPromptCooldown;
  }

  static Future<void> _markTesterPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _lastTesterPromptAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
