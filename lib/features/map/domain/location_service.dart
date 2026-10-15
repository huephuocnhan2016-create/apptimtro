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
}
