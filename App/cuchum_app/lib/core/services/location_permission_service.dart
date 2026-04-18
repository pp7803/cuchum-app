import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class TripLocationPoint {
  const TripLocationPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class LocationPermissionService {
  static bool get isAppleDesktopOrMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static Future<bool> ensureLocationPermission() async {
    if (!isAppleDesktopOrMobile) return true;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static Future<TripLocationPoint?> getCurrentTripLocation() async {
    if (!isAppleDesktopOrMobile) return null;

    final granted = await ensureLocationPermission();
    if (!granted) return null;

    try {
      final pos = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 12),
      );
      return TripLocationPoint(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
    } catch (_) {
      return null;
    }
  }
}
