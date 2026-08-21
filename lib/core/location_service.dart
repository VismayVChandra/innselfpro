import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Wraps geolocator's permission dance into one call that returns null
/// -- instead of throwing -- whenever location isn't available (denied
/// permission, disabled service, any platform error), so callers can
/// degrade to "just type it" instead of crashing.
class LocationService {
  final _geocoding = Geocoding();

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

  /// Turns coordinates back into a short human-readable address, e.g.
  /// "5th Block, Koramangala" -- best-effort: returns null on any
  /// failure (no network, no geocoder on this device, nothing usable in
  /// the result) rather than throwing, so a caller can just keep
  /// whatever the user already typed.
  Future<({String? address, String? pincode})?> reverseGeocode(
    double lat,
    double lng,
  ) async {
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final parts = [p.street, p.subLocality, p.locality]
          .where((s) => s != null && s.trim().isNotEmpty)
          .map((s) => s!.trim())
          .toSet() // street/subLocality/locality sometimes repeat verbatim
          .toList();
      if (parts.isEmpty) return null;
      final pincode = RegExp(r'^\d{6}$').hasMatch(p.postalCode ?? '') ? p.postalCode : null;
      return (address: parts.join(', '), pincode: pincode);
    } catch (_) {
      return null;
    }
  }
}
