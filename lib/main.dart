import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/app_theme.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Hold the native splash on screen until our Dart splash is ready to take
  // over — eliminates the bare-Flutter flash between native splash and our
  // first frame.
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  await initializeDateFormatting('ru_RU', null);
  await NotificationService.init();
  await StorageService.migrateIfNeeded();
  runApp(const DiaryApp());
}

class ThemeNotifier extends ChangeNotifier {
  AppThemeData _theme = AppThemes.all.first;
  AppThemeData get theme => _theme;

  Future<void> load() async {
    final id = await StorageService.loadThemeId();
    _theme = AppThemes.getById(id);
    notifyListeners();
  }

  Future<void> setTheme(String id) async {
    _theme = AppThemes.getById(id);
    await StorageService.saveThemeId(id);
    notifyListeners();
  }
}

class DiaryApp extends StatefulWidget {
  const DiaryApp({super.key});

  static final themeNotifier = ThemeNotifier();

  @override
  State<DiaryApp> createState() => _DiaryAppState();
}

class _DiaryAppState extends State<DiaryApp> {
  bool _themeReady = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await DiaryApp.themeNotifier.load();
    if (!mounted) return;
    setState(() => _themeReady = true);
    // The native splash can hand off to our Dart splash now.
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeReady) {
      // While theme is loading the native splash is still on top, so this
      // widget is never actually visible. Return a transparent placeholder.
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SizedBox.shrink(),
      );
    }

    return ListenableBuilder(
      listenable: DiaryApp.themeNotifier,
      builder: (context, _) {
        final t = DiaryApp.themeNotifier.theme;
        return MaterialApp(
          title: 'Дневник',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: t.primary,
              brightness: t.brightness,
            ),
            scaffoldBackgroundColor: t.background,
            useMaterial3: true,
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
