import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'core/constants.dart';
import 'core/notification_service.dart';
import 'core/theme.dart';
import 'core/utils.dart';
import 'presentation/providers/settings_providers.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.instance.initialize();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  tz_data.initializeTimeZones();
  final prefs = await SharedPreferences.getInstance();
  await _cleanupLegacyScreenerPrefs(prefs);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const EconAtlasApp(),
    ),
  );
}

Future<void> _cleanupLegacyScreenerPrefs(SharedPreferences prefs) async {
  await prefs.remove(AppConstants.prefPreferredRegions);
  await prefs.remove(AppConstants.prefScreenerPreset);
  await prefs.remove(AppConstants.prefScreenerMinQuality);
}

class EconAtlasApp extends ConsumerWidget {
  const EconAtlasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final timezone = ref.watch(chartTimezoneProvider);
    Formatters.setAbsoluteTimeZone(timezone.id);

    return MaterialApp.router(
      title: 'EconAtlas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final overlay = SystemUiOverlayStyle(
          systemNavigationBarColor: theme.scaffoldBackgroundColor,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay,
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: router,
    );
  }
}
