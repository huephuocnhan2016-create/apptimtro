import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';

class NotificationService {
  NotificationService(this._client);

  final ApiClient _client;
  final _messages = StreamController<RemoteMessage>.broadcast();
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  StreamSubscription<String>? _tokenRefresh;
  Stream<RemoteMessage> get messages => _messages.stream;

  Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    _foreground ??= FirebaseMessaging.onMessage.listen(_messages.add);
    _opened ??= FirebaseMessaging.onMessageOpenedApp.listen(_messages.add);
    final initial = await messaging.getInitialMessage();
    if (initial != null) _messages.add(initial);
    await registerToken(await messaging.getToken());
    _tokenRefresh ??= FirebaseMessaging.instance.onTokenRefresh.listen(
      registerToken,
    );
  }

  Future<void> registerToken(String? token) async {
    if (token == null || token.isEmpty) return;
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : defaultTargetPlatform == TargetPlatform.android
        ? 'android'
        : 'web';
    await _client.dio.post<void>(
      '/notifications/device-token',
      data: {'token': token, 'platform': platform},
    );
  }

  Future<void> removeToken() async {
    if (Firebase.apps.isEmpty) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _client.dio.delete<void>(
        '/notifications/device-token',
        data: {'token': token},
      );
    }
  }

  Future<void> dispose() async {
    await _foreground?.cancel();
    await _opened?.cancel();
    await _tokenRefresh?.cancel();
    await _messages.close();
  }
}
