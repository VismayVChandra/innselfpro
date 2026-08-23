import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../location_service.dart';

/// Shows InnSelf's own explanation before the OS permission prompt --
/// Play's location-permission policy requires this to appear first, not
/// after. Also routes a permanently-denied status to the phone's
/// Settings app, since Android won't show its own prompt again once a
/// user has denied twice.
///
/// Returns true when the caller should go ahead and call
/// [LocationService.getCurrentLocation], false to abandon.
Future<bool> confirmLocationUse(
  BuildContext context,
  LocationService locationService,
) async {
  final status = await locationService.currentPermissionStatus();
  if (status == LocationPermission.always || status == LocationPermission.whileInUse) {
    return true; // Already granted -- nothing to explain.
  }

  if (!context.mounted) return false;

  if (status == LocationPermission.deniedForever) {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Location permission needed'),
        content: const Text(
          "You've previously denied location access, so Android won't ask again automatically. "
          'Enable it from Settings to use this.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    if (openSettings == true) await locationService.openAppSettings();
    return false;
  }

  final proceed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Use your location?'),
      content: const Text(
        'InnSelf uses your location to match jobs and technicians by real distance, and to fill in '
        'your address automatically. It is only read when you tap "Use current location" -- never in '
        'the background.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  return proceed ?? false;
}
