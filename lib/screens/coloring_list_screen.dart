import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/coloring_service.dart';
import 'coloring_screen.dart';

/// Grid of available coloring pages. Tapping one opens [ColoringScreen].
class ColoringListScreen extends StatefulWidget {
  /// When true, returns the exported image path back to the caller after
  /// the user finishes a page (so it can be attached to a diary entry).
  final bool returnImagePath;

  const ColoringListScreen({super.key, this.returnImagePath = false});

  @override
  State<ColoringListScreen> createState() => _ColoringListScreenState();
}

class _ColoringListScreenState extends State<ColoringListScreen> {
  final Map<String, Uint8List> _previewCache = {};
  final Set<String> _withProgress = {};

  @override
  void initState() {
    super.initState();
    _scanProgress();
  }

  Future<void> _scanProgress() async {
    final found = <String>{};
    for (final p in ColoringService.pages) {
      if (await ColoringService.hasProgress(p.id)) found.add(p.id);
    }
    if (!mounted) return;
    setState(() {
      _withProgress
        ..clear()
        ..addAll(found);
    });
  }

  Future<Uint8List?> _previewBytes(ColoringPage page) async {
    if (_previewCache.containsKey(page.id)) return _previewCache[page.id];
    if (!_withProgress.contains(page.id)) return null;
    final bytes = await ColoringService.loadProgress(page.id);
    if (bytes != null) _previewCache[page.id] = bytes;
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;
    final pages = ColoringService.pages;

    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Раскраски',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: pages.length,
            itemBuilder: (ctx, i) {
              final page = pages[i];
              final inProgress = _withProgress.contains(page.id);
              return _PageCard(
                page: page,
                inProgress: inProgress,
                previewLoader: () => _previewBytes(page),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ColoringScreen(
                        page: page,
                        returnImagePath: widget.returnImagePath,
                      ),
                    ),
                  );
                  if (!mounted) return;
                  if (widget.returnImagePath && result is String) {
                    Navigator.pop(context, result);
                    return;
                  }
                  _previewCache.remove(page.id);
                  _scanProgress();
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PageCard extends StatelessWidget {
  final ColoringPage page;
  final bool inProgress;
  final Future<Uint8List?> Function() previewLoader;
  final VoidCallback onTap;

  const _PageCard({
    required this.page,
    required this.inProgress,
    required this.previewLoader,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = DiaryApp.themeNotifier.theme;
    return Material(
      color: t.cardColor,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.white),
                      FutureBuilder<Uint8List?>(
                        future: previewLoader(),
                        builder: (ctx, snap) {
                          if (snap.data != null) {
                            return Image.memory(
                              snap.data!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            );
                          }
                          return Image.asset(
                            page.assetPath,
                            fit: BoxFit.contain,
                          );
                        },
                      ),
                      if (inProgress)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: t.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'в процессе',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
