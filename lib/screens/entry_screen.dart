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
import '../services/database_service.dart';
import '../services/gemini_service.dart';
import '../services/mood_fallback.dart';
import '../services/lexicon_analyzer.dart';
import '../services/analysis_mode.dart';
import '../widgets/frosted_background.dart';

/// Full-screen entry editor — opens via Navigator.push.
/// Returns the saved DiaryEntry on pop, or null if cancelled.
class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _saving = false;
  String _textBeforeListening = '';
  bool _restarting = false;

  final List<String> _pendingPhotos = [];
  final ImagePicker _imagePicker = ImagePicker();

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' && _isListening && !_restarting) {
            _scheduleRestart();
          }
        },
        onError: (error) {
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
    } catch (_) {
      _speechAvailable = false;
    }
    if (mounted) setState(() {});
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
    } catch (_) {}
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
      } catch (_) {
        _pulseController.stop();
        _pulseController.reset();
        setState(() => _isListening = false);
      }
    }
  }

  Future<void> _pickPhoto({required ImageSource source}) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (image == null) return;
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(appDir.path, 'photos'));
      if (!photosDir.existsSync()) photosDir.createSync(recursive: true);
      final fileName =
          'photo_${DateTime.now().millisecondsSinceEpoch}${p.extension(image.path)}';
      final savedPath = p.join(photosDir.path, fileName);
      await File(image.path).copy(savedPath);
      setState(() => _pendingPhotos.add(savedPath));
    } catch (_) {}
  }

  void _removePhoto(int i) => setState(() => _pendingPhotos.removeAt(i));

  Future<void> _save() async {
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
    FocusScope.of(context).unfocus();

    final mode = await AnalysisModeStore.load();
    MoodAnalysis analysis;

    switch (mode) {
      case AnalysisMode.fast:
        analysis = MoodFallback.analyze(text);
        break;
      case AnalysisMode.lexicon:
        try {
          analysis = await LexiconAnalyzer.analyze(text);
        } catch (_) {
          analysis = MoodFallback.analyze(text);
        }
        break;
      case AnalysisMode.ai:
        MoodAnalysis fallback;
        try {
          fallback = await LexiconAnalyzer.analyze(text);
        } catch (_) {
          fallback = MoodFallback.analyze(text);
        }
        analysis = fallback;
        try {
          final aiResult = await GeminiService.analyze(text, '');
          if (aiResult != null) analysis = aiResult;
        } catch (_) {}
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

    if (!mounted) return;
    Navigator.pop(context, entry);
  }

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: t.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: t.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                elevation: 0,
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
                  : const Text(
                      'Сохранить',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
      body: FrostedBackground(
        theme: t,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 17,
                      height: 1.55,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Пиши, как хочешь...',
                      hintStyle: TextStyle(
                        color: t.textHint.withValues(alpha: 0.6),
                        fontSize: 17,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              if (_pendingPhotos.isNotEmpty)
                Container(
                  height: 84,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pendingPhotos.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(right: 8, top: 6),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
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
                                decoration: const BoxDecoration(
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
                    ),
                  ),
                ),
              _buildToolbar(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(t) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: t.cardColor.withValues(alpha: 0.6),
        border: Border(
          top: BorderSide(
            color: t.textHint.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, _) {
          if (_isListening) {
            return Row(
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: _circleButton(
                    color: Colors.red,
                    icon: Icons.stop_rounded,
                    onTap: _toggleMic,
                    glow: true,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
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
              ],
            );
          }
          return Row(
            children: [
              _circleButton(
                color: t.primary,
                icon: Icons.mic_none_rounded,
                onTap: _toggleMic,
              ),
              const SizedBox(width: 8),
              _circleButton(
                color: (t.primary as Color).withValues(alpha: 0.18),
                iconColor: t.primary,
                icon: Icons.photo_library_rounded,
                onTap: () => _pickPhoto(source: ImageSource.gallery),
              ),
              const SizedBox(width: 8),
              _circleButton(
                color: (t.primary as Color).withValues(alpha: 0.18),
                iconColor: t.primary,
                icon: Icons.camera_alt_rounded,
                onTap: () => _pickPhoto(source: ImageSource.camera),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _circleButton({
    required Color color,
    Color? iconColor,
    required IconData icon,
    required VoidCallback onTap,
    bool glow = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: glow
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: iconColor ?? Colors.white,
          size: 22,
        ),
      ),
    );
  }
}
