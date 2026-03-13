import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCjBrxP22lUQSvkvU_Ssu0tsU6ExFglyok',
    appId: '1:949594645691:android:0bd7ebafe5b75ac257f59e',
    messagingSenderId: '949594645691',
    projectId: 'boendakitchen-5206b',
    storageBucket: 'boendakitchen-5206b.firebasestorage.app',
  );
}