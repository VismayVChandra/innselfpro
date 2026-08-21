import 'dart:math';

/// Great-circle distance in kilometres. Mirrors
/// `public.distance_km` in migration 014 exactly, so "how far away"
/// reads the same whether it's computed here (the live feed) or there
/// (the new-job fan-out) -- one definition of "nearby", just expressed
/// twice because one runs on-device and one in Postgres.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final dLat = _radians(lat2 - lat1);
  final dLng = _radians(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_radians(lat1)) * cos(_radians(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

double _radians(double degrees) => degrees * pi / 180;

/// "3.2 km away" / "850 m away" for a distance the caller already knows
/// is non-null.
String formatDistance(double km) {
  if (km < 1) return '${(km * 1000).round()} m away';
  return '${km.toStringAsFixed(1)} km away';
}
