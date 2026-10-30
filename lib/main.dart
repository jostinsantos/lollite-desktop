import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'core/desktop_window.dart';

import 'core/storage/local_storage.dart';
import 'data/services/content_cache.dart';
import 'data/services/repo_manager.dart';
import 'data/services/library_service.dart';
import 'data/services/repo_prefs.dart';
import 'data/services/settings_service.dart';
import 'data/services/download_service.dart';
import 'data/services/ui_scale_service.dart';
import 'ui/shared/download_progress_overlay.dart';
import 'ui/shared/update_banner.dart';

import 'launcher/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  MediaKit.ensureInitialized();

  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(900, 560),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'LOL Lite',
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setTitle('LOL Lite');
    await windowManager.show();
    await windowManager.focus();
  });
  await DesktopWindowController.instance.init();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);

  final storage = LocalStorage();
  await storage.init();
  ContentCache.instance.bind(storage);

  final repoManager = RepoManager(storage);
  final libraryService = LibraryService(storage);
  final repoPrefs = RepoPrefs(storage);
  final settingsService = SettingsService(storage);

  // Descargas nativas
  try {
    DownloadService.instance.bind(storage);
    await DownloadService.instance.init();
  } catch (e) {
    debugPrint('[main] DownloadService.init: $e');
  }

  await Future.wait([
    repoManager.init(),
    libraryService.init(),
    settingsService.load(),
    UiScaleService.instance.load(),
  ]);

  // Forzar modo desktop en settings
  try {
    await settingsService.setMode(UiMode.desktop);
  } catch (_) {}

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: repoManager),
        ChangeNotifierProvider.value(value: libraryService),
        ChangeNotifierProvider.value(value: repoPrefs),
        ChangeNotifierProvider.value(value: settingsService),
        ChangeNotifierProvider.value(value: DownloadService.instance),
        ChangeNotifierProvider.value(value: UiScaleService.instance),
      ],
      child: const LolLiteDesktopApp(),
    ),
  );
}

final GlobalKey<NavigatorState> desktopNavigatorKey = GlobalKey<NavigatorState>();

class LolLiteDesktopApp extends StatelessWidget {
  const LolLiteDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LOL Lite',
      navigatorKey: desktopNavigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE50914),
          brightness: Brightness.dark,
          primary: const Color(0xFFE50914),
          onPrimary: Colors.white,
          surface: const Color(0xFF0F1115),
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0D10),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE50914),
            foregroundColor: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE50914),
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white38),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.white70),
        ),
      ),
      builder: (context, child) {
        // No usar context.watch aquí: el context del builder de MaterialApp
        // a veces no ve el MultiProvider tras hot-reload. ListenableBuilder
        // lee el singleton directamente.
        return ListenableBuilder(
          listenable: UiScaleService.instance,
          builder: (context, _) {
            final scale = UiScaleService.instance.scale;
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: UpdateGate(
                navigatorKey: desktopNavigatorKey,
                child: DownloadProgressOverlay(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
        );
      },
      home: const LauncherHome(),
    );
  }
}
