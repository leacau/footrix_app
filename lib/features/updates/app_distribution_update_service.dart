import 'dart:async';

import 'package:firebase_app_distribution/firebase_app_distribution.dart'
    as app_distribution;
import 'package:flutter/foundation.dart';

class AppDistributionUpdateService {
  static bool _alreadyChecked = false;

  static void checkForTesterUpdateInBackground() {
    if (_alreadyChecked || kIsWeb || !kReleaseMode) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    _alreadyChecked = true;
    Timer(const Duration(seconds: 3), () async {
      try {
        await app_distribution.updateIfNewReleaseAvailable();
      } catch (error) {
        debugPrint('App Distribution update check skipped: $error');
      }
    });
  }
}
