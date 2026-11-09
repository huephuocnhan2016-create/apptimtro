import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/auth/data/auth_api.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/user_api.dart';
import '../features/auth/domain/user.dart';
import '../features/chat/data/chat_api.dart';
import '../features/chat/data/message_repository.dart';
import '../features/payment/data/payment_api.dart';
import '../features/rooms/data/room_api.dart';
import '../features/rooms/data/room_repository.dart';
import '../features/map/domain/location_service.dart';
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

/// `true` khi splash đã đọc xong phiên đăng nhập cũ. Router dựa vào cờ này để
/// không đẩy nhầm người đã đăng nhập về login lúc app vừa mở.
final sessionRestoredProvider =
    NotifierProvider<SessionRestoredNotifier, bool>(SessionRestoredNotifier.new);

class SessionRestoredNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markRestored() => state = true;
}

final roomApiProvider = Provider(
  (ref) => RoomApi(ref.watch(apiClientProvider)),
);
final roomRepositoryProvider = Provider(
  (ref) => RoomRepository(ref.watch(roomApiProvider)),
);
final locationServiceProvider = Provider((_) => LocationService());

// ===== Firebase / chat =====
final chatApiProvider = Provider(
  (ref) => ChatApi(ref.watch(apiClientProvider)),
);
final paymentApiProvider = Provider(
  (ref) => PaymentApi(ref.watch(apiClientProvider)),
);
final firebaseAuthProvider = Provider((_) => FirebaseAuth.instance);
final firestoreProvider = Provider((_) => FirebaseFirestore.instance);
final messageRepositoryProvider = Provider(
  (ref) => MessageRepository(
    ref.watch(chatApiProvider),
    ref.watch(firestoreProvider),
  ),
);

// Access token của app chỉ sống 900 giây nên không thể sign-in Firebase một lần
// rồi quên: provider này chạy lại mỗi lần đổi user; còn khi JWT hết hạn,
// interceptor trong ApiClient tự refresh trước khi GET /auth/firebase-token.
final firebaseSignInProvider = FutureProvider<User?>((ref) async {
  final appUser = ref.watch(currentUserProvider);
  final auth = ref.watch(firebaseAuthProvider);
  if (appUser == null) {
    if (auth.currentUser != null) await auth.signOut();
    return null;
  }
  final token = await ref.watch(chatApiProvider).firebaseToken();
  final credential = await auth.signInWithCustomToken(token);
  return credential.user;
});
