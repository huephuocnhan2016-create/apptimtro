import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/auth/data/auth_api.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/user_api.dart';
import '../features/auth/domain/user.dart';
import '../features/rooms/data/room_api.dart';
import '../features/rooms/data/room_repository.dart';
import '../features/map/domain/location_service.dart';
import '../features/calls/data/call_api.dart';
import '../features/calls/data/call_repository.dart';
import '../features/notifications/data/notification_service.dart';
import 'network/api_client.dart';
import 'storage/token_storage.dart';

final tokenStorageProvider = Provider(
  (_) => TokenStorage(const FlutterSecureStorage()),
);
final apiClientProvider = Provider(
  (ref) => ApiClient(ref.watch(tokenStorageProvider)),
);
final authApiProvider = Provider(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);
final userApiProvider = Provider(
  (ref) => UserApi(ref.watch(apiClientProvider)),
);
final authRepositoryProvider = Provider(
  (ref) => AuthRepository(
    ref.watch(authApiProvider),
    ref.watch(tokenStorageProvider),
  ),
);
final currentUserProvider = NotifierProvider<UserNotifier, AppUser?>(UserNotifier.new);

class UserNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() => null;
  
  void setUser(AppUser? user) => state = user;
  void clearUser() => state = null;
}
final roomApiProvider = Provider(
  (ref) => RoomApi(ref.watch(apiClientProvider)),
);
final roomRepositoryProvider = Provider(
  (ref) => RoomRepository(ref.watch(roomApiProvider)),
);
final locationServiceProvider = Provider((_) => LocationService());
final callApiProvider = Provider(
  (ref) => CallApi(ref.watch(apiClientProvider)),
);
final callRepositoryProvider = Provider(
  (ref) => CallRepository(ref.watch(callApiProvider)),
);
final notificationServiceProvider = Provider(
  (ref) => NotificationService(ref.watch(apiClientProvider)),
);
