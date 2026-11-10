import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/chat/domain/conversation.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/payment/presentation/deposit_list_screen.dart';
import '../../features/payment/presentation/payment_screen.dart';
import '../../features/rooms/domain/room.dart';
import '../../features/rooms/presentation/room_detail_screen.dart';
import '../../features/rooms/presentation/room_form.dart';
import '../../features/rooms/presentation/room_search_screen.dart';
import '../../features/landlord/presentation/landlord_screens.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../providers.dart';
import 'app_shell.dart';
import 'auth_redirect.dart';
import 'route_error_screen.dart';

/// Router của app. Nghe [currentUserProvider] và [sessionRestoredProvider]:
/// đăng nhập/đăng xuất là router tự chạy lại [authRedirect].
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(currentUserProvider, (_, _) => refresh.value++);
  ref.listen(sessionRestoredProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    // Link "Về ứng dụng" của cổng thanh toán (trotot://...?txnRef=) được
    // chuyển thành /payment?txnRef= — nhưng chỉ sau khi đã kiểm tra đăng nhập.
    redirect: (context, state) => authRedirect(
      uri: state.uri,
      matchedLocation: state.matchedLocation,
      sessionRestored: ref.read(sessionRestoredProvider),
      loggedIn: ref.read(currentUserProvider) != null,
    ),
    errorBuilder: (_, _) =>
        const RouteErrorScreen(message: 'Không tìm thấy trang này.'),
    routes: _routes,
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

final _routes = <RouteBase>[
  GoRoute(
    path: '/splash',
    builder: (_, state) =>
        SplashScreen(from: state.uri.queryParameters['from']),
  ),
  GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
  GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
  GoRoute(
    path: '/register-role',
    builder: (_, _) => const RegisterRoleScreen(),
  ),
  GoRoute(
    path: '/phone',
    builder: (_, state) => PhoneInputScreen(
      role: state.uri.queryParameters['role'] == 'LANDLORD'
          ? UserRole.landlord
          : UserRole.student,
      isLogin: state.uri.queryParameters['flow'] == 'login',
    ),
  ),
  GoRoute(
    path: '/otp',
    builder: (_, state) {
      final extra = state.extra;
      if (extra is! Map<String, dynamic> ||
          extra['phone'] is! String ||
          (extra.containsKey('devOtp') &&
              extra['devOtp'] != null &&
              extra['devOtp'] is! String)) {
        return const AuthFlowExpiredScreen();
      }
      return OtpVerificationScreen(
        phone: extra['phone'] as String,
        devOtp: extra['devOtp'] as String?,
        role: state.uri.queryParameters['role'] == 'LANDLORD'
            ? UserRole.landlord
            : UserRole.student,
        isLogin: state.uri.queryParameters['flow'] == 'login',
      );
    },
  ),
  GoRoute(
    path: '/register/student',
    builder: (_, state) {
      final extra = state.extra;
      if (extra is! Map<String, Object> ||
          extra['phone'] is! String ||
          extra['verificationToken'] is! String) {
        return const AuthFlowExpiredScreen();
      }
      return StudentRegisterScreen(
        phone: extra['phone']! as String,
        verificationToken: extra['verificationToken']! as String,
      );
    },
  ),
  GoRoute(
    path: '/register/landlord',
    builder: (_, state) {
      final extra = state.extra;
      if (extra is! Map<String, Object> ||
          extra['phone'] is! String ||
          extra['verificationToken'] is! String) {
        return const AuthFlowExpiredScreen();
      }
      return LandlordRegisterScreen(
        phone: extra['phone']! as String,
        verificationToken: extra['verificationToken']! as String,
      );
    },
  ),
  // 4 tab chính dùng chung một thanh điều hướng; mỗi tab giữ lịch sử riêng.
  StatefulShellRoute.indexedStack(
    builder: (_, _, shell) => AppShell(shell: shell),
    branches: [
      StatefulShellBranch(
        routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())],
      ),
      StatefulShellBranch(
        routes: [GoRoute(path: '/map', builder: (_, _) => const MapScreen())],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/favorites',
            builder: (_, _) => const FavoritesScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        ],
      ),
    ],
  ),
  GoRoute(path: '/map-picker', builder: (_, _) => const MapPickerScreen()),
  GoRoute(path: '/chats', builder: (_, _) => const ChatListScreen()),
  GoRoute(
    path: '/chats/thread',
    builder: (_, state) {
      final conversation = state.extra;
      if (conversation is! ChatConversation) {
        return const RouteErrorScreen(
          message: 'Không xác định được cuộc trò chuyện.',
        );
      }
      return ChatScreen.withConversation(
        conversationId: conversation.id,
        peerUid: conversation.participantId,
        peerName: conversation.participantName ?? 'người dùng',
        roomId: conversation.roomId,
      );
    },
  ),
  GoRoute(path: '/rooms/search', builder: (_, _) => const RoomSearchScreen()),
  GoRoute(
    path: '/rooms/:id',
    builder: (_, state) =>
        RoomDetailScreen(roomId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/chat',
    builder: (_, state) {
      final room = state.extra;
      if (room is! Room) {
        return const RouteErrorScreen(
          message: 'Không xác định được chủ trọ để chat.',
        );
      }
      return ChatScreen(room: room);
    },
  ),
  GoRoute(
    path: '/payment',
    builder: (_, state) {
      final txnRef = state.uri.queryParameters['txnRef'];
      if (txnRef != null) return PaymentScreen(txnRef: txnRef);
      final room = state.extra;
      if (room is! Room) {
        return const RouteErrorScreen(
          message: 'Không xác định được phòng để đặt cọc.',
        );
      }
      return PaymentScreen(room: room);
    },
  ),
  GoRoute(path: '/deposits', builder: (_, _) => const DepositListScreen()),
  GoRoute(
    path: '/landlord',
    builder: (_, _) => const LandlordDashboardScreen(),
  ),
  GoRoute(path: '/landlord/rooms', builder: (_, _) => const MyRoomsScreen()),
  GoRoute(
    path: '/landlord/rooms/add',
    builder: (_, _) => const AddRoomScreen(),
  ),
  GoRoute(
    path: '/landlord/rooms/:id/edit',
    builder: (_, state) {
      final room = state.extra;
      return room is Room
          ? EditRoomScreen(room: room)
          : const RouteErrorScreen(
              message:
                  'Không xác định được phòng cần sửa. '
                  'Hãy mở lại từ danh sách phòng của bạn.',
            );
    },
  ),
];
