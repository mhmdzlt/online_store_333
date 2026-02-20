import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

enum LocationFailureReason {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class LocationLookupOutcome {
  final LocationResult? result;
  final LocationFailureReason? failure;

  const LocationLookupOutcome._({
    this.result,
    this.failure,
  });

  const LocationLookupOutcome.success(LocationResult data)
      : this._(result: data);

  const LocationLookupOutcome.failure(LocationFailureReason reason)
      : this._(failure: reason);

  bool get isSuccess => result != null;
}

class LocationResult {
  final double latitude;
  final double longitude;
  final String? city;
  final String? area;
  final String? addressLine;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    this.city,
    this.area,
    this.addressLine,
  });
}

class LocationService {
  static Future<LocationLookupOutcome> getCurrentLocationOutcome() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationLookupOutcome.failure(
        LocationFailureReason.serviceDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const LocationLookupOutcome.failure(
        LocationFailureReason.permissionDenied,
      );
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationLookupOutcome.failure(
        LocationFailureReason.permissionDeniedForever,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String? city;
      String? area;
      String? addressLine;

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          city = place.locality ?? place.administrativeArea;
          area = place.subLocality ?? place.subAdministrativeArea;
          final street = place.street;
          final name = place.name;
          if (street != null && street.trim().isNotEmpty) {
            addressLine = street;
          } else if (name != null && name.trim().isNotEmpty) {
            addressLine = name;
          }
        }
      } catch (_) {}

      return LocationLookupOutcome.success(
        LocationResult(
          latitude: position.latitude,
          longitude: position.longitude,
          city: city,
          area: area,
          addressLine: addressLine,
        ),
      );
    } catch (_) {
      return const LocationLookupOutcome.failure(
          LocationFailureReason.unavailable);
    }
  }

  static Future<LocationResult?> getCurrentLocation() async {
    final outcome = await getCurrentLocationOutcome();
    return outcome.result;
  }

  static Future<void> openRelevantSettings(LocationFailureReason reason) async {
    switch (reason) {
      case LocationFailureReason.serviceDisabled:
        await Geolocator.openLocationSettings();
        break;
      case LocationFailureReason.permissionDenied:
      case LocationFailureReason.permissionDeniedForever:
        await Geolocator.openAppSettings();
        break;
      case LocationFailureReason.unavailable:
        break;
    }
  }
}
