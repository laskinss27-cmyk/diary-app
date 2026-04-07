import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/app_theme.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  bool _loading = true;
  bool _onboarded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await DiaryApp.themeNotifier.load();
    final onboarded = await StorageService.isOnboarded();
    setState(() {
      _onboarded = onboarded;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFFFFF0F5),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFFE8A0BF)),
          ),
        ),
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
          home: _onboarded
              ? const HomeScreen()
              : OnboardingScreen(
                  onComplete: () => setState(() => _onboarded = true),
                ),
        );
      },
    );
  }
}
