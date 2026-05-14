import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // 🔥 WEB - Reemplazá con tus valores reales de Firebase Console
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyB6QmbGwkvSUw-HMz-v6NfKZ_fmrFoW1wg",
    authDomain: "footrix-dc5a7.firebaseapp.com",
    projectId: "footrix-dc5a7",
    storageBucket: "footrix-dc5a7.firebasestorage.app",
    messagingSenderId: "122416562566",
    appId: "1:122416562566:web:a3c58a974861a0c7df6c07",
  );

  // 🔥 ANDROID - Reemplazá con tus valores reales
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyB6QmbGwkvSUw-HMz-v6NfKZ_fmrFoW1wg",
    authDomain: "footrix-dc5a7.firebaseapp.com",
    projectId: "footrix-dc5a7",
    storageBucket: "footrix-dc5a7.firebasestorage.app",
    messagingSenderId: "122416562566",
    appId: "1:122416562566:web:a3c58a974861a0c7df6c07",
  );

  // 🔥 iOS - Reemplazá con tus valores reales
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyB6QmbGwkvSUw-HMz-v6NfKZ_fmrFoW1wg",
    authDomain: "footrix-dc5a7.firebaseapp.com",
    projectId: "footrix-dc5a7",
    storageBucket: "footrix-dc5a7.firebasestorage.app",
    messagingSenderId: "122416562566",
    appId: "1:122416562566:web:a3c58a974861a0c7df6c07",
  );

  // 🔥 macOS - Reemplazá con tus valores reales
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: "AIzaSyB6QmbGwkvSUw-HMz-v6NfKZ_fmrFoW1wg",
    authDomain: "footrix-dc5a7.firebaseapp.com",
    projectId: "footrix-dc5a7",
    storageBucket: "footrix-dc5a7.firebasestorage.app",
    messagingSenderId: "122416562566",
    appId: "1:122416562566:web:a3c58a974861a0c7df6c07",
  );
}
