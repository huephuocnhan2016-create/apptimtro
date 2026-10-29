import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user.dart';
import '../../features/auth/presentation/auth_screens.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/rooms/domain/room.dart';
import '../../features/rooms/presentation/room_detail_screen.dart';
import '../../features/rooms/presentation/room_form.dart';
import '../../features/rooms/presentation/room_search_screen.dart';
import '../../features/landlord/presentation/landlord_screens.dart';
import '../../features/favorites/presentation/favorites_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
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
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
    GoRoute(path: '/map', builder: (_, _) => const MapScreen()),
    GoRoute(path: '/map-picker', builder: (_, _) => const MapPickerScreen()),
    GoRoute(path: '/favorites', builder: (_, _) => const FavoritesScreen()),
    GoRoute(path: '/rooms/search', builder: (_, _) => const RoomSearchScreen()),
    GoRoute(
      path: '/rooms/:id',
      builder: (_, state) =>
          RoomDetailScreen(roomId: state.pathParameters['id']!),
    ),
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
            : const AddRoomScreen();
      },
    ),
  ],
);
