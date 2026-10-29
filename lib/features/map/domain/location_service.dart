import 'dart:async';

import 'package:flutter/widgets.dart' show Locale;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  Future<Position> currentPosition() async {
    final permission = await Permission.locationWhenInUse.request();
    if (!permission.isGranted) {
      throw StateError('Quyền truy cập vị trí chưa được cấp.');
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Vui lòng bật dịch vụ định vị trên thiết bị.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  Future<String?> addressFrom(double latitude, double longitude) async {
    try {
      final placemarks = await Geocoding(locale: const Locale('vi', 'VN'))
          .placemarkFromCoordinates(latitude, longitude)
          .timeout(const Duration(seconds: 8));
      if (placemarks.isEmpty) return null;
      return _formatAddress(placemarks.first);
    } catch (_) {
      return null;
    }
  }

  String? _formatAddress(Placemark placemark) {
    const countryNames = {'vietnam', 'viet nam', 'việt nam', 'vn'};
    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

    final parts = [
      placemark.street,
      placemark.subLocality,
      placemark.locality,
      placemark.administrativeArea,
    ]
        .whereType<String>()
        .expand((part) => part.split(','))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);

    final address = <String>[];
    for (final part in parts) {
      final normalized = normalize(part);
      if (countryNames.contains(normalized)) continue;
      final duplicated = address.any((existing) {
        final current = normalize(existing);
        return current == normalized ||
            current.contains(normalized) ||
            normalized.contains(current);
      });
      if (!duplicated) address.add(part);
    }
    return address.isEmpty ? null : address.join(', ');
  }
}
