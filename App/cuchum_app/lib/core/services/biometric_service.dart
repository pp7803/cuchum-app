// Platform setup required:
// iOS  → Info.plist: NSFaceIDUsageDescription
// Android → AndroidManifest.xml: <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
//           MainActivity extends FlutterFragmentActivity (not FlutterActivity)

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Device supports biometric APIs **and** user has enrolled at least one biometric
  /// (Face ID / fingerprint / …). PIN-only without enrolled biometrics returns false.
  static Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!supported || !canCheck) return false;
      final types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (e) {
      debugPrint('BiometricService.isAvailable error: $e');
      return false;
    }
  }

  /// Get the types of biometrics available on the device
  static Future<List<BiometricType>> getAvailableTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('BiometricService.getAvailableTypes error: $e');
      return [];
    }
  }

  /// Prompt the user to authenticate using biometrics (or device PIN as fallback)
  static Future<bool> authenticate({
    String reason = 'Xác thực danh tính để tiếp tục',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow device PIN/pattern fallback
          stickyAuth: true,     // keep prompt if app goes to background
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      debugPrint('BiometricService.authenticate error: $e');
      return false;
    }
  }

  /// Returns a human-readable icon-label for the strongest available biometric
  static Future<String> getBiometricLabel() async {
    final types = await getAvailableTypes();
    if (types.contains(BiometricType.face)) return 'Face ID';
    if (types.contains(BiometricType.fingerprint)) return 'Vân tay';
    if (types.contains(BiometricType.iris)) return 'Mống mắt';
    return 'Sinh trắc học';
  }
}
