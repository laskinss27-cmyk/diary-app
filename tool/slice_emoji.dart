// Slices a sprite sheet of emoji on a transparent canvas into separate
// PNGs. Finds horizontal bands of content, then cells within each band,
// then the exact bounding box of each cell.
//
// Usage: dart run tool/slice_emoji.dart <source.png> <out_dir>
import 'dart:io';
import 'package:image/image.dart' as img;

const _alphaThreshold = 16;

bool _opaque(img.Image im, int x, int y) =>
    im.getPixel(x, y).a > _alphaThreshold;

/// Finds runs of `true` in a projection profile, merging gaps smaller
/// than [minGap] so anti-aliasing specks don't split a face in two.
List<(int, int)> _runs(List<bool> profile, {int minGap = 4}) {
  final runs = <(int, int)>[];
  int? start;
  int gap = 0;
  for (int i = 0; i < profile.length; i++) {
    if (profile[i]) {
      if (start == null) {
        start = i;
      }
      gap = 0;
    } else if (start != null) {
      gap++;
      if (gap >= minGap) {
        runs.add((start, i - gap));
        start = null;
        gap = 0;
      }
    }
  }
  if (start != null) runs.add((start, profile.length - 1 - gap));
  return runs;
}

void main(List<String> args) {
  final src = img.decodePng(File(args[0]).readAsBytesSync())!;
  final outDir = Directory(args[1])..createSync(recursive: true);

  // If there is no alpha channel at all, bail out loudly.
  final hasAlpha = src.numChannels == 4;
  if (!hasAlpha) {
    stderr.writeln('No alpha channel — expected transparent background.');
    exit(1);
  }

  final rowProfile = List<bool>.generate(src.height, (y) {
    for (int x = 0; x < src.width; x++) {
      if (_opaque(src, x, y)) return true;
    }
    return false;
  });

  int n = 0;
  final bands = _runs(rowProfile, minGap: 6);
  for (final (rowIdx, band) in bands.indexed) {
    final colProfile = List<bool>.generate(src.width, (x) {
      for (int y = band.$1; y <= band.$2; y++) {
        if (_opaque(src, x, y)) return true;
      }
      return false;
    });
    final cells = _runs(colProfile, minGap: 6);
    for (final (colIdx, cell) in cells.indexed) {
      // Exact bbox inside the cell.
      int top = band.$2, bottom = band.$1;
      for (int y = band.$1; y <= band.$2; y++) {
        for (int x = cell.$1; x <= cell.$2; x++) {
          if (_opaque(src, x, y)) {
            if (y < top) top = y;
            if (y > bottom) bottom = y;
            break;
          }
        }
      }
      final w = cell.$2 - cell.$1 + 1;
      final h = bottom - top + 1;
      if (w < 16 || h < 16) continue; // skip specks
      final crop =
          img.copyCrop(src, x: cell.$1, y: top, width: w, height: h);
      final name =
          'face_r${rowIdx + 1}_c${(colIdx + 1).toString().padLeft(2, '0')}.png';
      File('${outDir.path}/$name').writeAsBytesSync(img.encodePng(crop));
      n++;
      stdout.writeln('$name  ${w}x$h');
    }
  }
  stdout.writeln('Done: $n faces');
}
