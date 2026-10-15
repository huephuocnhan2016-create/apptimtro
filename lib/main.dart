import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import 'core/constants/app_constants.dart';
import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

bool firebaseAvailable = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  if ([apiKey, appId, senderId, projectId].every((value) => value.isNotEmpty)) {
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: senderId,
          projectId: projectId,
        ),
      );
      firebaseAvailable = true;
    } on FirebaseException catch (error) {
      debugPrint('Firebase initialization failed: ${error.message}');
    }
  }
  runApp(const ProviderScope(child: TroTotApp()));
}

class TroTotApp extends ConsumerStatefulWidget {
  const TroTotApp({super.key});

  @override
  ConsumerState<TroTotApp> createState() => _TroTotAppState();
}

class _TroTotAppState extends ConsumerState<TroTotApp> {
  bool _notificationInitStarted = false;
  StreamSubscription<RemoteMessage>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    if (firebaseAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messageSubscription = ref
            .read(notificationServiceProvider)
            .messages
            .listen(_handleMessage);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserProvider, (previous, current) {
      if (current != null && firebaseAvailable && !_notificationInitStarted) {
        _notificationInitStarted = true;
        ref.read(notificationServiceProvider).initialize().catchError((
          Object error,
        ) {
          debugPrint('Notification initialization failed: $error');
          _notificationInitStarted = false;
        });
      }
    });
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }

  void _handleMessage(RemoteMessage message) {
    if (message.data['type'] == 'incoming_call') {
      final callId = message.data['callId'];
      if (callId is String && callId.isNotEmpty) {
        appRouter.push('/calls/$callId/incoming');
      }
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}
