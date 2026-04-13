import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:workmanager/workmanager.dart';
import 'core/constants.dart';
import 'core/notification_service.dart';
import 'core/theme.dart';
import 'core/utils.dart';
import 'presentation/providers/dashboard_widget_providers.dart';
import 'presentation/providers/settings_providers.dart';
import 'router.dart';

@pragma('vm:entry-point')
void dashboardWidgetCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    ui.DartPluginRegistrant.ensureInitialized();
    tz_data.initializeTimeZones();
    final prefs = await SharedPreferences.getInstance();
    await _publishDashboardWidgetWithPrefs(prefs, preferNetwork: true);
    return true;
  });
}

@pragma('vm:entry-point')
Future<void> dashboardWidgetInteractiveCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  ui.DartPluginRegistrant.ensureInitialized();
  if (uri == null) return;

  final isRefreshAction = uri.host == 'refresh' || uri.path == '/refresh';
  if (!isRefreshAction) return;

  final prefs = await SharedPreferences.getInstance();
  await _publishDashboardWidgetWithPrefs(prefs, preferNetwork: true);
}

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
  await _configureDashboardWidgetBackground();

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

Future<void> _configureDashboardWidgetBackground() async {
  if (kIsWeb || !Platform.isAndroid) return;
  await Workmanager().initialize(
    dashboardWidgetCallbackDispatcher,
  );
  await Workmanager().registerPeriodicTask(
    AppConstants.dashboardWidgetPeriodicTaskUniqueName,
    AppConstants.dashboardWidgetPeriodicTaskName,
    // 15 min is Android's minimum for WorkManager periodic tasks.
    // Was 30 min — reduced for more timely widget updates during
    // market hours. In practice Android may still batch/delay this
    // by a few minutes for battery optimization.
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
  await HomeWidget.registerInteractivityCallback(
    dashboardWidgetInteractiveCallback,
  );
}

Future<void> _publishDashboardWidgetWithPrefs(
  SharedPreferences prefs, {
  required bool preferNetwork,
}) async {
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  try {
    await container
        .read(dashboardHomeWidgetServiceProvider)
        .publish(preferNetwork: preferNetwork);
  } finally {
    container.dispose();
  }
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
          child: _HomeWidgetLaunchBridge(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      routerConfig: router,
    );
  }
}

class _HomeWidgetLaunchBridge extends StatefulWidget {
  const _HomeWidgetLaunchBridge({required this.child});

  final Widget child;

  @override
  State<_HomeWidgetLaunchBridge> createState() =>
      _HomeWidgetLaunchBridgeState();
}

class _HomeWidgetLaunchBridgeState extends State<_HomeWidgetLaunchBridge> {
  StreamSubscription<Uri?>? _subscription;
  String? _lastHandledRoute;
  DateTime? _lastHandledAt;

  @override
  void initState() {
    super.initState();
    _subscription = HomeWidget.widgetClicked.listen(_handleUri);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      _handleUri(initialUri);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _handleUri(Uri? uri) {
    if (!mounted || uri == null) return;
    final path = uri.path.isNotEmpty
        ? uri.path
        : uri.host.isNotEmpty
            ? '/${uri.host}'
            : '/dashboard';
    final location = uri.hasQuery ? '$path?${uri.query}' : path;
    final now = DateTime.now();
    if (_lastHandledRoute == location &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(milliseconds: 600)) {
      return;
    }
    _lastHandledRoute = location;
    _lastHandledAt = now;

    if (location == '/dashboard') {
      router.go(location);
      return;
    }
    router.push(location);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
