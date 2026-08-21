import 'package:geolocator/geolocator.dart';

/// Wraps geolocator's permission dance into one call that returns null
/// -- instead of throwing -- whenever location isn't available (denied
/// permission, disabled service, any platform error), so callers can
/// degrade to "just type it" instead of crashing.
class LocationService {
  Future<({double lat, double lng})?> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      return (lat: position.latitude, lng: position.longitude);
    } catch (_) {
      return null;
    }
  }
}
