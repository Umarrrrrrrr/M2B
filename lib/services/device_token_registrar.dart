import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'push_token_service.dart';

class DeviceTokenRegistrar extends StatefulWidget {
  const DeviceTokenRegistrar({
    super.key,
    required this.user,
    required this.child,
  });

  final User user;
  final Widget child;

  @override
  State<DeviceTokenRegistrar> createState() => _DeviceTokenRegistrarState();
}

class _DeviceTokenRegistrarState extends State<DeviceTokenRegistrar> {
  final _messaging = FirebaseMessaging.instance;
  final _tokenService = PushTokenService();
  StreamSubscription<String>? _tokenSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _messaging.setAutoInitEnabled(true);
      await _messaging.requestPermission();
      await _registerToken();
      _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => _registerToken(tokenOverride: token),
      );
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  Future<void> _registerToken({String? tokenOverride}) async {
    final token = tokenOverride ?? await _messaging.getToken();
    if (token == null) return;
    final platform = describeEnum(defaultTargetPlatform);
    await _tokenService.registerToken(
      uid: widget.user.uid,
      token: token,
      platform: platform,
    );
  }

  @override
  void dispose() {
    _tokenSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
