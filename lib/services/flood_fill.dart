import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;

/// Parameters bundled for [compute]. Plain map so it crosses the isolate
/// boundary cheaply.
class FloodFillRequest {
  final Uint8List rgba;
  /// 1 = pixel was painted by the user, 0 = original artwork pixel.
  /// Same length as [rgba] / 4.
  final Uint8List mask;
  final int width;
  final int height;
  final int startX;
  final int startY;
  final int targetR;
  final int targetG;
  final int targetB;
  final int targetA;
  /// True = erasing. Eraser fills only over user-painted pixels (mask==1)
  /// regardless of brightness, so dark colors can be erased without eating
  /// the original contour lines.
  final bool eraser;
  /// Pixels darker than this on average are considered "borders" and stop
  /// a normal (non-eraser) fill. Tuned for printed line-art scans.
  final int borderThreshold;

  const FloodFillRequest({
    required this.rgba,
    required this.mask,
    required this.width,
    required this.height,
    required this.startX,
    required this.startY,
    required this.targetR,
    required this.targetG,
    required this.targetB,
    required this.targetA,
    this.eraser = false,
    this.borderThreshold = 110,
  });
}

class FloodFillResult {
  final Uint8List rgba;
  final Uint8List mask;
  const FloodFillResult(this.rgba, this.mask);
}

/// Flood-fills from (startX, startY). Runs in an isolate via [compute].
Future<FloodFillResult> floodFill(FloodFillRequest req) =>
    compute(_floodFillImpl, req);

FloodFillResult _floodFillImpl(FloodFillRequest req) {
  final rgba = Uint8List.fromList(req.rgba);
  final mask = Uint8List.fromList(req.mask);
  final w = req.width;
  final h = req.height;
  if (req.startX < 0 || req.startX >= w || req.startY < 0 || req.startY >= h) {
    return FloodFillResult(rgba, mask);
  }

  int idx(int x, int y) => (y * w + x) * 4;
  int mIdx(int x, int y) => y * w + x;

  final seed = idx(req.startX, req.startY);
  final mSeed = mIdx(req.startX, req.startY);
  final seedR = rgba[seed];
  final seedG = rgba[seed + 1];
  final seedB = rgba[seed + 2];
  final seedLum = (seedR + seedG + seedB) ~/ 3;
  final seedPainted = mask[mSeed] == 1;

  if (req.eraser) {
    // Refuse to erase original artwork — only user-painted pixels.
    if (!seedPainted) return FloodFillResult(rgba, mask);
  } else {
    // Refuse to fill if user tapped on a contour line.
    if (!seedPainted && seedLum < req.borderThreshold) {
      return FloodFillResult(rgba, mask);
    }
    if (seedR == req.targetR &&
        seedG == req.targetG &&
        seedB == req.targetB) {
      return FloodFillResult(rgba, mask);
    }
  }

  const tol = 40;

  bool fillable(int x, int y) {
    final p = idx(x, y);
    final m = mIdx(x, y);
    if (req.eraser) {
      // Only spread across pixels the user painted, that match the seed.
      if (mask[m] != 1) return false;
    } else {
      // Don't cross borders unless the pixel was already user-painted
      // (in which case the user is overwriting their own fill).
      if (mask[m] != 1) {
        final lum = (rgba[p] + rgba[p + 1] + rgba[p + 2]) ~/ 3;
        if (lum < req.borderThreshold) return false;
      }
    }
    final r = rgba[p];
    final g = rgba[p + 1];
    final b = rgba[p + 2];
    return (r - seedR).abs() <= tol &&
        (g - seedG).abs() <= tol &&
        (b - seedB).abs() <= tol;
  }

  void paint(int x, int y) {
    final p = idx(x, y);
    rgba[p] = req.targetR;
    rgba[p + 1] = req.targetG;
    rgba[p + 2] = req.targetB;
    rgba[p + 3] = req.targetA;
    mask[mIdx(x, y)] = req.eraser ? 0 : 1;
  }

  // Scanline flood fill.
  final stack = <List<int>>[
    [req.startX, req.startY]
  ];
  while (stack.isNotEmpty) {
    final point = stack.removeLast();
    int x = point[0];
    int y = point[1];

    int xl = x;
    while (xl >= 0 && fillable(xl, y)) {
      xl--;
    }
    xl++;

    bool spanAbove = false;
    bool spanBelow = false;
    int xr = xl;
    while (xr < w && fillable(xr, y)) {
      paint(xr, y);

      if (y > 0) {
        final ab = fillable(xr, y - 1);
        if (!spanAbove && ab) {
          stack.add([xr, y - 1]);
          spanAbove = true;
        } else if (spanAbove && !ab) {
          spanAbove = false;
        }
      }
      if (y < h - 1) {
        final bl = fillable(xr, y + 1);
        if (!spanBelow && bl) {
          stack.add([xr, y + 1]);
          spanBelow = true;
        } else if (spanBelow && !bl) {
          spanBelow = false;
        }
      }
      xr++;
    }
  }

  return FloodFillResult(rgba, mask);
}
