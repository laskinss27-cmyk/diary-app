import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../main.dart';
import '../services/coloring_service.dart';
import '../services/flood_fill.dart';

/// Раскраска одной картинки.
class ColoringScreen extends StatefulWidget {
  final ColoringPage page;

  /// If true, when the user taps "Готово" the screen pops with the path
  /// to the exported PNG so the caller can attach it to a diary entry.
  final bool returnImagePath;

  const ColoringScreen({
    super.key,
    required this.page,
    this.returnImagePath = false,
  });

  @override
  State<ColoringScreen> createState() => _ColoringScreenState();
}

class _ColoringScreenState extends State<ColoringScreen> {
  Uint8List? _rgba;
  Uint8List? _mask;
  int _w = 0;
  int _h = 0;
  ui.Image? _image;

  Color _color = const Color(0xFFE57373); // soft red default
  bool _eraser = false;
  bool _eyedropper = false;
  bool _busy = false;
  bool _dirty = false;
  final TransformationController _viewerController = TransformationController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ColoringService.loadCanvas(widget.page);
    if (!mounted) return;
    _rgba = res.rgba;
    _mask = res.mask;
    _w = res.width;
    _h = res.height;
    await _refreshImage();
  }

  Future<void> _refreshImage() async {
    if (_rgba == null) return;
    final img = await ColoringService.rgbaToUiImage(_rgba!, _w, _h);
    if (!mounted) {
      img.dispose();
      return;
    }
    final old = _image;
    setState(() => _image = img);
    old?.dispose();
  }

  void _pickColorAt(int x, int y) {
    if (_rgba == null) return;
    final p = (y * _w + x) * 4;
    final picked = Color.fromARGB(
        255, _rgba![p], _rgba![p + 1], _rgba![p + 2]);
    setState(() {
      _color = picked;
      _eyedropper = false;
      _eraser = false;
    });
  }

  Future<void> _fillAt(int x, int y) async {
    if (_rgba == null || _mask == null || _busy) return;
    if (_eyedropper) {
      _pickColorAt(x, y);
      return;
    }
    setState(() => _busy = true);
    final c = _eraser ? const Color(0xFFFFFFFF) : _color;
    final result = await floodFill(FloodFillRequest(
      rgba: _rgba!,
      mask: _mask!,
      width: _w,
      height: _h,
      startX: x,
      startY: y,
      targetR: (c.r * 255).round(),
      targetG: (c.g * 255).round(),
      targetB: (c.b * 255).round(),
      targetA: 255,
      eraser: _eraser,
    ));
    if (!mounted) return;
    _rgba = result.rgba;
    _mask = result.mask;
    _dirty = true;
    await _refreshImage();
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _saveProgress({bool silent = false}) async {
    if (_rgba == null || _mask == null) return;
    final png = await ColoringService.encodePng(_rgba!, _w, _h);
    await ColoringService.saveProgress(widget.page.id, png, _mask!);
    _dirty = false;
    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Прогресс сохранён')),
      );
    }
  }

  Future<void> _resetCanvas() async {
    final t = DiaryApp.themeNotifier.theme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Начать заново?',
            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Текущая раскраска будет стёрта. Это действие нельзя отменить.',
          style: TextStyle(color: t.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: TextStyle(color: t.textHint)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Стереть', style: TextStyle(color: t.accent)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ColoringService.clearProgress(widget.page.id);
    await _load();
  }

  Future<void> _finish() async {
    if (_rgba == null) return;
    setState(() => _busy = true);
    try {
      final path = await ColoringService.exportToPhotos(_rgba!, _w, _h);
      // Keep progress around so the user can come back and tweak.
      await _saveProgress(silent: true);
      if (!mounted) return;
      if (widget.returnImagePath) {
        Navigator.pop(context, path);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Сохранено. Можно прикрепить к записи.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickColor() async {
    final t = DiaryApp.themeNotifier.theme;
    Color picked = _color;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Выбери цвет',
            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _color,
            onColorChanged: (c) => picked = c,
            enableAlpha: false,
            labelTypes: const [],
            displayThumbColor: true,
            paletteType: PaletteType.hsvWithHue,
            pickerAreaHeightPercent: 0.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: t.textHint)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _color = picked;
                _eraser = false;
              });
              Navigator.pop(ctx);
            },
            child: Text('OK', style: TextStyle(color: t.primary)),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_dirty) return true;
    await _saveProgress(silent: true);
    return true;
  }

  @override
  void dispose() {
    _image?.dispose();
    _viewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _onWillPop();
        if (ok && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: t.background,
        appBar: AppBar(
          backgroundColor: t.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Раскраска',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'Сохранить прогресс',
              icon: const Icon(Icons.save_outlined, color: Colors.white),
              onPressed: () => _saveProgress(),
            ),
            IconButton(
              tooltip: 'Начать заново',
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _resetCanvas,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Container(
                color: Colors.white,
                child: _image == null
                    ? const Center(child: CircularProgressIndicator())
                    : Center(
                        child: AspectRatio(
                          aspectRatio: _w / _h,
                          child: LayoutBuilder(
                            builder: (ctx, c) {
                              return InteractiveViewer(
                                transformationController: _viewerController,
                                minScale: 1.0,
                                maxScale: 6.0,
                                clipBehavior: Clip.hardEdge,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapUp: (details) {
                                    final x = (details.localPosition.dx /
                                            c.maxWidth *
                                            _w)
                                        .round()
                                        .clamp(0, _w - 1);
                                    final y = (details.localPosition.dy /
                                            c.maxHeight *
                                            _h)
                                        .round()
                                        .clamp(0, _h - 1);
                                    _fillAt(x, y);
                                  },
                                  child: CustomPaint(
                                    painter: _CanvasPainter(_image!),
                                    size: Size(c.maxWidth, c.maxHeight),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
              ),
            ),
            if (_busy)
              const LinearProgressIndicator(minHeight: 2),
            _toolbar(t),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(dynamic t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: t.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Color swatch
            GestureDetector(
              onTap: _pickColor,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _eraser ? Colors.white : _color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _eraser
                        ? t.textHint.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.15),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.palette_outlined,
                  color: _eraser
                      ? t.textHint
                      : (_color.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Eraser toggle
            _toolButton(
              icon: Icons.cleaning_services_outlined,
              active: _eraser,
              tooltip: 'Ластик',
              onTap: () => setState(() {
                _eraser = !_eraser;
                if (_eraser) _eyedropper = false;
              }),
              t: t,
            ),
            const SizedBox(width: 8),
            _toolButton(
              icon: Icons.colorize_rounded,
              active: _eyedropper,
              tooltip: 'Пипетка',
              onTap: () => setState(() {
                _eyedropper = !_eyedropper;
                if (_eyedropper) _eraser = false;
              }),
              t: t,
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _busy ? null : _finish,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: Text(widget.returnImagePath ? 'Прикрепить' : 'Готово'),
              style: ElevatedButton.styleFrom(
                backgroundColor: t.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required bool active,
    required String tooltip,
    required VoidCallback onTap,
    required dynamic t,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active
                ? t.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? t.primary : t.textHint.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(icon, color: active ? t.primary : t.textSecondary),
        ),
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  final ui.Image image;
  _CanvasPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Offset.zero & size;
    canvas.drawImageRect(image, src, dst, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter old) => old.image != image;
}
