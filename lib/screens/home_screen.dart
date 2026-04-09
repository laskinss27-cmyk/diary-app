import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart'
    show ListenMode;
import '../main.dart';
import '../models/diary_entry.dart';
import '../services/storage_service.dart';
import '../services/database_service.dart';
import '../services/gemini_service.dart';
import '../services/mood_fallback.dart';
import '../services/lexicon_analyzer.dart';
import '../services/analysis_mode.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/entry_card.dart';
import '../widgets/gentle_crisis_dialog.dart';
import '../widgets/mood_flask.dart';
import '../widgets/welcome_banner.dart';
import 'settings_screen.dart';
import 'report_screen.dart';
import 'calendar_screen.dart';
import 'help_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<DiaryEntry> _entries = [];
  final TextEditingController _textController = TextEditingController();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _saving = false;
  String _textBeforeListening = '';
  bool _restarting = false;

  String _userName = '';
  AvatarData _avatar = AvatarData.defaultAvatar;
  WelcomeContext? _welcomeContext;
  late final DateTime _openedAt = DateTime.now();

  // Photo attachments
  final List<String> _pendingPhotos = [];
  final ImagePicker _imagePicker = ImagePicker();

  // Animation for mic button
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initSpeech();
    _loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final loaded = await StorageService.loadEntries();
    final profile = await StorageService.loadProfile();
    final avatar = await StorageService.loadAvatar();
    // Compute welcome context only on the first load (cold start),
    // not on every refresh after returning from a child screen.
    WelcomeContext? ctx = _welcomeContext;
    if (ctx == null) {
      final lastOpen = await StorageService.loadLastOpen();
      ctx = computeWelcomeContext(lastOpen, _openedAt);
      // Stamp this open so the next launch can compute its own context.
      await StorageService.saveLastOpen(_openedAt);
    }
    setState(() {
      _entries = loaded;
      _userName = profile['name'] ?? '';
      _avatar = avatar;
      _welcomeContext = ctx;
    });
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' && _isListening && !_restarting) {
            _scheduleRestart();
          }
        },
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          if (_isListening &&
              !_restarting &&
              (error.errorMsg == 'error_speech_timeout' ||
                  error.errorMsg == 'error_no_match')) {
            _scheduleRestart();
            return;
          }
          if (error.errorMsg == 'error_busy') return;
          if (!_isListening) return;
          setState(() => _isListening = false);
          _pulseController.stop();
          _pulseController.reset();
        },
      );
      debugPrint('Speech available: $_speechAvailable');
    } catch (e) {
      debugPrint('Speech init exception: $e');
      _speechAvailable = false;
    }
    setState(() {});
  }

  void _scheduleRestart() {
    _restarting = true;
    Future.delayed(const Duration(milliseconds: 400), () {
      _restarting = false;
      if (_isListening) _restartListening();
    });
  }

  Future<void> _restartListening() async {
    if (!_isListening) return;
    _textBeforeListening = _textController.text;
    try {
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 150));
      if (!_isListening) return;
      await _speech.listen(
        onResult: _onSpeechResult,
        localeId: 'ru_RU',
        listenFor: const Duration(seconds: 120),
        pauseFor: const Duration(seconds: 60),
        listenMode: ListenMode.dictation,
      );
    } catch (e) {
      debugPrint('Restart listen error: $e');
    }
  }

  void _onSpeechResult(dynamic result) {
    final newWords = result.recognizedWords as String;
    if (newWords.isEmpty) return;
    if (_textBeforeListening.isEmpty) {
      _textController.text = newWords;
    } else {
      _textController.text = '$_textBeforeListening $newWords';
    }
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
  }

  Future<void> _toggleMic() async {
    if (_isListening) {
      _pulseController.stop();
      _pulseController.reset();
      setState(() => _isListening = false);
      try {
        await _speech.stop();
      } catch (_) {}
    } else {
      if (!_speechAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Микрофон недоступен')),
        );
        return;
      }
      _textBeforeListening = _textController.text;
      setState(() => _isListening = true);
      _pulseController.repeat(reverse: true);
      try {
        await _speech.listen(
          onResult: _onSpeechResult,
          localeId: 'ru_RU',
          listenFor: const Duration(seconds: 120),
          pauseFor: const Duration(seconds: 30),
        );
      } catch (e) {
        debugPrint('Listen error: $e');
        _pulseController.stop();
        _pulseController.reset();
        setState(() => _isListening = false);
      }
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (image == null) return;

      // Copy to app directory for persistence
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'photos'));
      if (!photosDir.existsSync()) {
        photosDir.createSync(recursive: true);
      }

      final fileName =
          'photo_${DateTime.now().millisecondsSinceEpoch}${p.extension(image.path)}';
      final savedPath = p.join(photosDir.path, fileName);
      await File(image.path).copy(savedPath);

      setState(() => _pendingPhotos.add(savedPath));
    } catch (e) {
      debugPrint('Photo pick error: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (image == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'photos'));
      if (!photosDir.existsSync()) {
        photosDir.createSync(recursive: true);
      }

      final fileName =
          'photo_${DateTime.now().millisecondsSinceEpoch}${p.extension(image.path)}';
      final savedPath = p.join(photosDir.path, fileName);
      await File(image.path).copy(savedPath);

      setState(() => _pendingPhotos.add(savedPath));
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  void _removePhoto(int index) {
    setState(() => _pendingPhotos.removeAt(index));
  }

  Future<void> _addEntry() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _saving) return;

    if (_isListening) {
      _pulseController.stop();
      _pulseController.reset();
      setState(() => _isListening = false);
      try {
        await _speech.stop();
      } catch (_) {}
    }

    setState(() => _saving = true);

    final mode = await AnalysisModeStore.load();
    MoodAnalysis analysis;

    switch (mode) {
      case AnalysisMode.fast:
        analysis = MoodFallback.analyze(text);
        break;
      case AnalysisMode.lexicon:
        try {
          analysis = await LexiconAnalyzer.analyze(text);
        } catch (e) {
          debugPrint('Lexicon analyzer error: $e');
          analysis = MoodFallback.analyze(text);
        }
        break;
      case AnalysisMode.ai:
        // AI with double fallback: lexicon → fast.
        MoodAnalysis fallback;
        try {
          fallback = await LexiconAnalyzer.analyze(text);
        } catch (_) {
          fallback = MoodFallback.analyze(text);
        }
        analysis = fallback;
        try {
          final aiResult = await GeminiService.analyze(text, '');
          if (aiResult != null) {
            analysis = aiResult;
            debugPrint('AI analysis used');
          } else {
            debugPrint('AI returned null, using offline fallback');
          }
        } catch (e) {
          debugPrint('AI analysis error: $e');
        }
        break;
    }

    final entry = DiaryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      date: DateTime.now(),
      mood: analysis.emoji,
      analysis: analysis,
      photoPaths: List.from(_pendingPhotos),
    );

    await DatabaseService.insertEntry(entry);

    // Убираем фокус с поля ввода → клавиатура скрывается → снова
    // видна колба (её анимацию налива иначе пользователь пропустит).
    if (mounted) FocusScope.of(context).unfocus();

    setState(() {
      _entries.insert(0, entry);
      _textController.clear();
      _pendingPhotos.clear();
      _saving = false;
    });

    // Если анализ обнаружил кризисные маркеры — мягко предложим помощь.
    // Делаем после setState, чтобы список успел обновиться, и диалог
    // появился уже поверх нормального состояния UI.
    if (_isCrisisAnalysis(analysis) && mounted) {
      // Небольшая задержка, чтобы пользователь успел увидеть, что
      // его запись сохранилась, и не почувствовал, что диалог —
      // это "ответ" на написанное.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      await GentleCrisisDialog.show(context);
    }
  }

  /// Проверяет, содержит ли анализ признаки кризисного состояния.
  /// Оба анализатора (LexiconAnalyzer и MoodFallback) в этом случае
  /// помечают запись через keywords ("кризисное состояние",
  /// "суицидальные мысли", "самоповреждение") и ставят score = 1.
  bool _isCrisisAnalysis(MoodAnalysis a) {
    if (a.score <= 1) return true;
    for (final k in a.keywords) {
      final low = k.toLowerCase();
      if (low.contains('кризис') ||
          low.contains('суицид') ||
          low.contains('самоповрежд')) {
        return true;
      }
    }
    return false;
  }

  Future<void> _deleteEntry(int index) async {
    final entry = _entries[index];
    await DatabaseService.deleteEntry(entry.id);
    setState(() => _entries.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.primary,
        title: const Text(
          'Дневник',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border_rounded, color: Colors.white),
            tooltip: 'Если тебе тяжело',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
            tooltip: 'Календарь',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CalendarScreen()),
              );
              _loadData(); // Refresh after calendar
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
            tooltip: 'Отчёт за неделю',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReportScreen(entries: _entries),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Настройки',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _loadData();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // When the keyboard is up, hide the welcome banner and mood flask
          // so the input card + a glimpse of recent entries remain visible
          // and the layout doesn't overflow. User is focused on writing —
          // decorations are not needed in that moment.
          if (MediaQuery.of(context).viewInsets.bottom == 0) ...[
            // Warm welcome banner — animated on cold start, persistent thereafter.
            if (_welcomeContext != null)
              WelcomeBanner(
                userName: _userName,
                avatar: _avatar,
                context: _welcomeContext!,
                now: _openedAt,
              ),
            // Mood flask — visual summary of the last N entries.
            MoodFlask(entries: _entries),
          ],
          // Input card with animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
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
              children: [
                Text(
                  'Как прошёл твой день?',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _textController,
                  maxLines: 4,
                  style: TextStyle(color: t.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Напиши или надиктуй запись...',
                    hintStyle:
                        TextStyle(color: t.textHint.withValues(alpha: 0.5)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: t.primary.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: t.primary.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.primary),
                    ),
                    filled: true,
                    fillColor: t.brightness == Brightness.dark
                        ? t.background
                        : t.background.withValues(alpha: 0.5),
                  ),
                ),
                // Photo preview strip
                if (_pendingPhotos.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 72,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pendingPhotos.length,
                      itemBuilder: (context, i) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(_pendingPhotos[i]),
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removePhoto(i),
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Action row
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, _) {
                    if (_isListening) {
                      return _buildRecordingRow(t);
                    }
                    return _buildNormalRow(t);
                  },
                ),
              ],
            ),
          ),
          // Entries list
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(DiaryApp.themeNotifier.theme.emoji,
                            style: const TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          'Здесь появятся твои записи',
                          style: TextStyle(
                            color: t.textHint,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      return EntryCard(
                        entry: _entries[index],
                        onDelete: () => _deleteEntry(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalRow(dynamic t) {
    return Row(
      children: [
        GestureDetector(
          onTap: _toggleMic,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic_none, color: Colors.white, size: 22),
          ),
        ),
        const SizedBox(width: 6),
        // Photo buttons
        GestureDetector(
          onTap: _pickPhoto,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (t.primary as Color).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.photo_library_rounded,
                color: t.primary, size: 20),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: _takePhoto,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (t.primary as Color).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.camera_alt_rounded, color: t.primary, size: 20),
          ),
        ),
        const Spacer(),
        _buildSaveButton(t),
      ],
    );
  }

  Widget _buildRecordingRow(dynamic t) {
    return Row(
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: GestureDetector(
            onTap: _toggleMic,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: const Icon(Icons.stop_rounded,
                  color: Colors.white, size: 24),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Запись... Нажми СТОП',
            style: TextStyle(
              color: Colors.red,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        _buildSaveButton(t),
      ],
    );
  }

  Widget _buildSaveButton(dynamic t) {
    return ElevatedButton(
      onPressed: _saving ? null : _addEntry,
      style: ElevatedButton.styleFrom(
        backgroundColor: t.primary as Color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      child: _saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('Сохранить'),
    );
  }
}
