import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// One coloring page on disk + in assets.
class ColoringPage {
  final String id;
  final String assetPath;
  const ColoringPage({required this.id, required this.assetPath});
}

class ColoringService {
  /// Working canvas size. We downscale on load so flood fill is responsive
  /// even on cheap devices. 800px keeps detail without melting the CPU.
  static const int kWorkingSize = 800;

  /// All built-in pages bundled with the app.
  static List<ColoringPage> get pages => List.generate(
        7,
        (i) => ColoringPage(
          id: 'coloring_${i + 1}',
          assetPath: 'assets/coloring/coloring_${i + 1}.jpg',
        ),
      );

  /// Where progress PNGs live.
  static Future<Directory> _progressDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'coloring'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<File> _progressFile(String pageId) async {
    final dir = await _progressDir();
    return File(p.join(dir.path, '$pageId.png'));
  }

  static Future<File> _maskFile(String pageId) async {
    final dir = await _progressDir();
    return File(p.join(dir.path, '$pageId.mask'));
  }

  static Future<Uint8List?> _loadMask(String pageId, int expectedLen) async {
    final f = await _maskFile(pageId);
    if (!f.existsSync()) return null;
    final bytes = await f.readAsBytes();
    if (bytes.length != expectedLen) return null;
    return bytes;
  }

  static Future<void> _saveMask(String pageId, Uint8List mask) async {
    final f = await _maskFile(pageId);
    await f.writeAsBytes(mask, flush: true);
  }

  /// Returns the saved progress PNG bytes for a page, or null if none.
  static Future<Uint8List?> loadProgress(String pageId) async {
    final f = await _progressFile(pageId);
    if (!f.existsSync()) return null;
    return f.readAsBytes();
  }

  static Future<void> saveProgress(
      String pageId, Uint8List pngBytes, Uint8List mask) async {
    final f = await _progressFile(pageId);
    await f.writeAsBytes(pngBytes, flush: true);
    await _saveMask(pageId, mask);
  }

  static Future<void> clearProgress(String pageId) async {
    final f = await _progressFile(pageId);
    if (f.existsSync()) await f.delete();
    final m = await _maskFile(pageId);
    if (m.existsSync()) await m.delete();
  }

  static Future<bool> hasProgress(String pageId) async {
    final f = await _progressFile(pageId);
    return f.existsSync();
  }

  /// Loads either the saved progress (if any) or the original asset, and
  /// returns it as raw RGBA bytes downscaled to [kWorkingSize] on the long
  /// side. Also returns dimensions of the working buffer.
  static Future<({Uint8List rgba, Uint8List mask, int width, int height})>
      loadCanvas(ColoringPage page) async {
    final progress = await loadProgress(page.id);
    final Uint8List sourceBytes;
    if (progress != null) {
      sourceBytes = progress;
    } else {
      final data = await rootBundle.load(page.assetPath);
      sourceBytes = data.buffer.asUint8List();
    }

    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      throw StateError('Не удалось прочитать картинку ${page.assetPath}');
    }

    img.Image working = decoded;
    final maxSide = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    if (maxSide > kWorkingSize) {
      final scale = kWorkingSize / maxSide;
      working = img.copyResize(
        decoded,
        width: (decoded.width * scale).round(),
        height: (decoded.height * scale).round(),
        interpolation: img.Interpolation.average,
      );
    }

    // Force RGBA layout we can mutate directly.
    final rgba = Uint8List(working.width * working.height * 4);
    int i = 0;
    for (final pixel in working) {
      rgba[i++] = pixel.r.toInt();
      rgba[i++] = pixel.g.toInt();
      rgba[i++] = pixel.b.toInt();
      rgba[i++] = 255;
    }

    final pixelCount = working.width * working.height;
    Uint8List? mask;
    if (progress != null) {
      mask = await _loadMask(page.id, pixelCount);
    }
    mask ??= Uint8List(pixelCount);

    return (
      rgba: rgba,
      mask: mask,
      width: working.width,
      height: working.height,
    );
  }

  /// Encodes the current RGBA buffer to PNG.
  static Future<Uint8List> encodePng(
      Uint8List rgba, int width, int height) async {
    final image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      numChannels: 4,
    );
    return Uint8List.fromList(img.encodePng(image));
  }

  /// Wraps RGBA bytes into a ui.Image for painting.
  static Future<ui.Image> rgbaToUiImage(
      Uint8List rgba, int width, int height) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  /// Saves the finished canvas as a PNG into the photos folder so it can
  /// be attached to a diary entry. Returns the full path.
  static Future<String> exportToPhotos(
      Uint8List rgba, int width, int height) async {
    final png = await encodePng(rgba, width, height);
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'photos'));
    if (!photosDir.existsSync()) photosDir.createSync(recursive: true);
    final fileName = 'coloring_${DateTime.now().millisecondsSinceEpoch}.png';
    final path = p.join(photosDir.path, fileName);
    await File(path).writeAsBytes(png, flush: true);
    return path;
  }
}

