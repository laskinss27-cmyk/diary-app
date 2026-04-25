import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../main.dart';
import '../models/app_theme.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/pdf_service.dart';
import '../services/gemini_service.dart';
import '../services/analysis_mode.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/city_autocomplete.dart';
import '../widgets/disclaimer_dialog.dart';
import 'achievements_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _noteController = TextEditingController();
  String _city = '';
  AvatarData _avatar = AvatarData.defaultAvatar;
  late String _selectedThemeId;

  // Notifications
  bool _notifEnabled = false;
  int _notifHour = 21;
  int _notifMinute = 0;

  // API settings
  final _apiUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _apiModelController = TextEditingController();
  bool _testing = false;
  String? _testResult;
  String _selectedPreset = 'builtin';

  // Analysis mode
  AnalysisMode _analysisMode = AnalysisMode.lexicon;

  @override
  void initState() {
    super.initState();
    _selectedThemeId = DiaryApp.themeNotifier.theme.id;
    _loadData();
  }

  Future<void> _loadData() async {
    final profile = await StorageService.loadProfile();
    _nameController.text = profile['name'] ?? '';
    _ageController.text = profile['age'] ?? '';
    _noteController.text = profile['note'] ?? '';
    _city = profile['city'] ?? '';

    final avatar = await StorageService.loadAvatar();
    final notifSettings = await NotificationService.getSettings();
    final apiConfig = await ApiConfig.load();
    final mode = await AnalysisModeStore.load();

    setState(() {
      _avatar = avatar;
      _notifEnabled = notifSettings.enabled;
      _notifHour = notifSettings.hour;
      _notifMinute = notifSettings.minute;
      _apiUrlController.text = apiConfig.baseUrl;
      _apiKeyController.text = apiConfig.apiKey;
      _apiModelController.text = apiConfig.model;
      // Detect which preset matches
      _selectedPreset = _detectPreset(apiConfig);
      _analysisMode = mode;
    });
  }

  Future<void> _setAnalysisMode(AnalysisMode mode) async {
    setState(() => _analysisMode = mode);
    await AnalysisModeStore.save(mode);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Способ анализа: ${mode.title}'),
          backgroundColor: t.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _detectPreset(ApiConfig config) {
    if (config.baseUrl == ApiConfig.presets['builtin']!.baseUrl &&
        config.apiKey == ApiConfig.presets['builtin']!.apiKey) {
      return 'builtin';
    }
    if (config.baseUrl == ApiConfig.presets['openai']!.baseUrl) {
      return 'openai';
    }
    if (config.baseUrl == ApiConfig.presets['gemini']!.baseUrl) {
      return 'gemini';
    }
    return 'custom';
  }

  Future<void> _saveProfile() async {
    await StorageService.saveProfile(
      name: _nameController.text.trim(),
      age: _ageController.text.trim(),
      note: _noteController.text.trim(),
      city: _city.trim(),
    );
    await StorageService.saveAvatar(_avatar);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Профиль сохранён'),
          backgroundColor: t.primary,
        ),
      );
    }
  }

  void _applyPreset(String presetId) {
    final preset = ApiConfig.presets[presetId];
    if (preset == null) return;
    setState(() {
      _selectedPreset = presetId;
      _apiUrlController.text = preset.baseUrl;
      if (preset.apiKey.isNotEmpty) {
        _apiKeyController.text = preset.apiKey;
      } else if (presetId != 'builtin') {
        _apiKeyController.text = '';
      }
      _apiModelController.text = preset.model;
      _testResult = null;
    });
  }

  Future<void> _saveApiConfig() async {
    final config = ApiConfig(
      baseUrl: _apiUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      model: _apiModelController.text.trim(),
    );
    await ApiConfig.save(config);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('API настройки сохранены'),
          backgroundColor: t.primary,
        ),
      );
    }
  }

  Future<void> _resetApi() async {
    await ApiConfig.reset();
    final def = ApiConfig.defaultConfig;
    setState(() {
      _selectedPreset = 'builtin';
      _apiUrlController.text = def.baseUrl;
      _apiKeyController.text = def.apiKey;
      _apiModelController.text = def.model;
      _testResult = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Сброшено на встроенный API'),
          backgroundColor: t.primary,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    final config = ApiConfig(
      baseUrl: _apiUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      model: _apiModelController.text.trim(),
    );

    if (!config.isConfigured) {
      setState(() => _testResult = 'Заполните все поля');
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
    });

    final result = await GeminiService.testConnection(config);
    if (mounted) {
      setState(() {
        _testing = false;
        if (result.startsWith('ok')) {
          final model = result.contains(':') ? result.split(':')[1] : '';
          _testResult = 'AI работает! (модель: $model)';
        } else {
          switch (result) {
            case 'invalid':
              _testResult = 'Неверный API ключ';
            case 'rate_limit':
              _testResult = 'Превышен лимит запросов';
            case 'forbidden':
              _testResult = 'Доступ запрещён';
            case 'network':
              _testResult = 'Ошибка сети, проверьте URL и подключение';
            case 'empty':
              _testResult = 'Заполните все поля';
            default:
              _testResult = 'Ошибка: $result';
          }
        }
      });
    }
  }

  Future<void> _toggleNotifications(bool enabled) async {
    if (enabled) {
      final perm = await NotificationService.requestPermissions();
      if (!perm.notificationsGranted) {
        if (mounted) _showPermissionDeniedDialog();
        return;
      }
      await NotificationService.scheduleDaily(_notifHour, _notifMinute);
      if (!perm.exactAlarmGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Точное время не разрешено — напоминание может приходить с задержкой',
            ),
            backgroundColor: t.accent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else {
      await NotificationService.cancel();
    }
    setState(() => _notifEnabled = enabled);
  }

  void _showPermissionDeniedDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Нужно разрешение',
            style:
                TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Чтобы напоминания приходили, разреши уведомления в настройках приложения.',
          style: TextStyle(color: t.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: t.textHint)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              AppSettings.openAppSettings(type: AppSettingsType.notification);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: t.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Открыть настройки'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickNotifTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _notifHour, minute: _notifMinute),
    );
    if (time == null) return;
    setState(() {
      _notifHour = time.hour;
      _notifMinute = time.minute;
    });
    if (_notifEnabled) {
      await NotificationService.scheduleDaily(_notifHour, _notifMinute);
    }
  }

  Future<void> _exportPdf() async {
    final entries = await StorageService.loadEntries();
    if (entries.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Нет записей для экспорта'),
            backgroundColor: t.accent,
          ),
        );
      }
      return;
    }

    // Show disclaimer before export
    if (mounted) {
      final confirmed = await DisclaimerDialog.showBeforeShare(context);
      if (!confirmed) return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Формирую PDF...'),
          backgroundColor: t.primary,
          duration: const Duration(seconds: 1),
        ),
      );
    }

    try {
      final profile = await StorageService.loadProfile();
      await PdfService.exportEntries(
        entries: entries,
        profile: profile,
        title: 'Дневник настроения',
      );
    } catch (e) {
      debugPrint('PDF export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка PDF: $e'),
            backgroundColor: t.accent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  AppThemeData get t => DiaryApp.themeNotifier.theme;

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: t.textHint.withValues(alpha: 0.5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.primary.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.primary.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.primary),
        ),
        filled: true,
        fillColor: t.brightness == Brightness.dark
            ? t.background
            : t.background.withValues(alpha: 0.5),
      );

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _noteController.dispose();
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _apiModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.primary,
        title: const Text(
          'Настройки',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- Профиль ---
            _card(children: [
              Text('Профиль',
                  style: TextStyle(
                      color: t.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                'Эти данные включаются в отчёт для вашего специалиста.',
                style: TextStyle(color: t.textHint, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Center(
                child: AvatarPicker(
                  current: _avatar,
                  onChanged: (a) => setState(() => _avatar = a),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameController,
                style: TextStyle(color: t.textPrimary),
                decoration: _inputDecoration('Имя или псевдоним'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _ageController,
                style: TextStyle(color: t.textPrimary),
                decoration: _inputDecoration('Возраст'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                style: TextStyle(color: t.textPrimary),
                decoration:
                    _inputDecoration('Заметка для специалиста (необязательно)'),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              CityAutocomplete(
                initialValue: _city,
                theme: t,
                onChanged: (v) => _city = v,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Сохранить профиль'),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // --- Analysis mode ---
            _card(children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded, color: t.primary, size: 22),
                  const SizedBox(width: 8),
                  Text('Способ анализа настроения',
                      style: TextStyle(
                          color: t.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Выберите, как приложение будет оценивать ваши записи. Все офлайн-режимы работают без интернета и не отправляют ваши тексты никуда.',
                style: TextStyle(color: t.textHint, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              for (final mode in AnalysisMode.values) ...[
                _modeOption(mode),
                if (mode != AnalysisMode.ai) const SizedBox(height: 8),
              ],
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: t.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: t.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Во всех режимах кризисные фразы (мысли о суициде и самоповреждении) распознаются отдельным защитным слоем.',
                        style: TextStyle(
                            color: t.textSecondary, fontSize: 11, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // --- AI API ---
            _card(children: [
              Row(
                children: [
                  Icon(Icons.psychology_rounded, color: t.primary, size: 22),
                  const SizedBox(width: 8),
                  Text('AI подключение',
                      style: TextStyle(
                          color: t.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Подключите любой OpenAI-совместимый API для анализа настроения.',
                style: TextStyle(color: t.textHint, fontSize: 13),
              ),
              const SizedBox(height: 14),

              // Preset buttons
              Text('Быстрый выбор:',
                  style: TextStyle(
                      color: t.textHint,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _presetChip('builtin', 'Встроенный'),
                  _presetChip('openai', 'OpenAI'),
                  _presetChip('gemini', 'Gemini'),
                  _presetChip('custom', 'Свой API'),
                ],
              ),
              const SizedBox(height: 14),

              // URL
              Text('API URL', style: TextStyle(color: t.textHint, fontSize: 12)),
              const SizedBox(height: 4),
              TextField(
                controller: _apiUrlController,
                style: TextStyle(color: t.textPrimary, fontSize: 13),
                decoration: _inputDecoration('https://api.example.com/v1/chat/completions'),
              ),
              const SizedBox(height: 10),

              // Key
              Text('API ключ', style: TextStyle(color: t.textHint, fontSize: 12)),
              const SizedBox(height: 4),
              TextField(
                controller: _apiKeyController,
                style: TextStyle(color: t.textPrimary, fontSize: 13),
                obscureText: true,
                decoration: _inputDecoration('sk-...'),
              ),
              const SizedBox(height: 10),

              // Model
              Text('Модель', style: TextStyle(color: t.textHint, fontSize: 12)),
              const SizedBox(height: 4),
              TextField(
                controller: _apiModelController,
                style: TextStyle(color: t.textPrimary, fontSize: 13),
                decoration: _inputDecoration('gpt-4o-mini, claude-sonnet-4-6, gemini-2.0-flash...'),
              ),
              const SizedBox(height: 14),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveApiConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Сохранить'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _testing ? null : _testConnection,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.primary,
                        side: BorderSide(color: t.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _testing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: t.primary))
                          : const Text('Проверить'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Reset button
              if (_selectedPreset != 'builtin')
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _resetApi,
                    child: Text('Сбросить на встроенный',
                        style: TextStyle(color: t.textHint, fontSize: 13)),
                  ),
                ),

              // Test result
              if (_testResult != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _testResult!.contains('работает')
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFCE4EC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testResult!.contains('работает')
                            ? Icons.check_circle
                            : Icons.error_outline,
                        color: _testResult!.contains('работает')
                            ? Colors.green
                            : t.accent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            color: _testResult!.contains('работает')
                                ? Colors.green[700]
                                : t.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 16),

            // --- Напоминания ---
            _card(children: [
              Row(
                children: [
                  Icon(Icons.notifications_active_rounded,
                      color: t.primary, size: 22),
                  const SizedBox(width: 8),
                  Text('Напоминания',
                      style: TextStyle(
                          color: t.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ежедневное напоминание о записи',
                      style: TextStyle(color: t.textPrimary, fontSize: 14),
                    ),
                  ),
                  Switch.adaptive(
                    value: _notifEnabled,
                    onChanged: _toggleNotifications,
                    activeColor: t.primary,
                  ),
                ],
              ),
              if (_notifEnabled) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: t.accent.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 18, color: t.accent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Если напоминания не приходят',
                              style: TextStyle(
                                color: t.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'На Xiaomi/Redmi и подобных:\n'
                        '• Разреши автозапуск приложения\n'
                        '• Сними ограничения батареи (нет ограничений)\n'
                        '• Разреши уведомления и точные будильники',
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 11.5,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _hintButton(
                            'Уведомления',
                            Icons.notifications_outlined,
                            () => AppSettings.openAppSettings(
                                type: AppSettingsType.notification),
                          ),
                          _hintButton(
                            'Батарея',
                            Icons.battery_saver_outlined,
                            () => AppSettings.openAppSettings(
                                type: AppSettingsType.batteryOptimization),
                          ),
                          _hintButton(
                            'Все настройки',
                            Icons.settings_outlined,
                            () => AppSettings.openAppSettings(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickNotifTime,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: t.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, color: t.primary, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Время: ${_notifHour.toString().padLeft(2, '0')}:${_notifMinute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.edit, color: t.textHint, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 16),

            // --- Тема ---
            _card(children: [
              Text('Тема оформления',
                  style: TextStyle(
                      color: t.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.9,
                ),
                itemCount: AppThemes.all.length,
                itemBuilder: (context, i) {
                  final theme = AppThemes.all[i];
                  final isSelected = theme.id == _selectedThemeId;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedThemeId = theme.id);
                      DiaryApp.themeNotifier.setTheme(theme.id);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: theme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isSelected ? theme.primary : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(theme.emoji,
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(height: 4),
                          Text(theme.name,
                              style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ]),
            const SizedBox(height: 16),

            // --- Экспорт ---
            _card(children: [
              Text('Экспорт данных',
                  style: TextStyle(
                      color: t.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _exportPdf,
                  icon: Icon(Icons.picture_as_pdf_rounded,
                      color: t.primary, size: 20),
                  label: Text('Экспорт в PDF',
                      style: TextStyle(color: t.textSecondary)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: t.primary.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // --- Соглашение ---
            Center(
              child: TextButton.icon(
                onPressed: () => DisclaimerDialog.showAgreement(context),
                icon: Icon(Icons.description_outlined,
                    color: t.textHint, size: 18),
                label: Text(
                  'Пользовательское соглашение',
                  style: TextStyle(
                    color: t.textHint,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // --- Attribution ---
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Офлайн-анализ использует словарь RuSentiLex (ИСП РАН), '
                  'распространяется по лицензии CC BY-NC-SA 4.0.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: t.textHint.withValues(alpha: 0.7),
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // --- Мои достижения ---
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AchievementsScreen(),
                  ),
                ),
                icon: Icon(Icons.emoji_events_outlined,
                    color: t.primary, size: 20),
                label: Text(
                  'Мои достижения',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: t.primary.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _modeOption(AnalysisMode mode) {
    final isSelected = _analysisMode == mode;
    final icon = switch (mode) {
      AnalysisMode.fast => Icons.flash_on_rounded,
      AnalysisMode.lexicon => Icons.menu_book_rounded,
      AnalysisMode.ai => Icons.auto_awesome_rounded,
    };
    return GestureDetector(
      onTap: () => _setAnalysisMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? t.primary.withValues(alpha: 0.12)
              : t.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? t.primary
                : t.primary.withValues(alpha: 0.18),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? t.primary : t.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: isSelected ? Colors.white : t.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        mode.title,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.check_circle, color: t.primary, size: 16),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mode.description,
                    style: TextStyle(
                      color: t.textHint,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hintButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: t.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: t.accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(String id, String label) {
    final isSelected = _selectedPreset == id;
    return GestureDetector(
      onTap: () => _applyPreset(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? t.primary : t.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? t.primary : t.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : t.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: t.cardShadow.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
