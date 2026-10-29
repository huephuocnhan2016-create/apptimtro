import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() => runApp(const ProviderScope(child: TroTotApp()));

class TroTotApp extends StatelessWidget {
  const TroTotApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: AppConstants.appName,
    theme: AppTheme.light,
    routerConfig: appRouter,
    debugShowCheckedModeBanner: false,
  );
}
