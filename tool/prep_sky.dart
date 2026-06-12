// Prepares Sergey's sky art for the app: trims transparent margins,
// downsizes to sane dimensions, and converts baked black backgrounds to
// alpha (туча 2 came as grey-on-black with no transparency).
//
// Usage: dart run tool/prep_sky.dart "<srcDir>" <outDir>
import 'dart:io';
import 'package:image/image.dart' as img;

const _jobs = [
  ('солнце.png', 'sun.png', 460, false),
  ('луна.png', 'moon.png', 420, false),
  ('облако 1.png', 'cloud1.png', 640, false),
  ('облако 2.png', 'cloud2.png', 640, false),
  ('туча.png', 'dark1.png', 640, false),
  ('туча 2.png', 'dark2.png', 640, true), // black background → alpha
];

void main(List<String> args) {
  final srcDir = args[0];
  final outDir = Directory(args[1])..createSync(recursive: true);

  for (final (srcName, outName, maxW, blackToAlpha) in _jobs) {
    final file = File('$srcDir/$srcName');
    if (!file.existsSync()) {
      stderr.writeln('SKIP missing: $srcName');
      continue;
    }
    var im = img.decodePng(file.readAsBytesSync())!;
    im = im.convert(numChannels: 4);

    // Detect a baked background: if the image has no real transparency.
    int transparent = 0;
    for (final p in im) {
      if (p.a < 8) transparent++;
    }
    final hasAlpha = transparent > im.width * im.height * 0.02;

    if (blackToAlpha || !hasAlpha) {
      // Luminance → alpha: black stays invisible, the cloud becomes a
      // soft semi-transparent shape. Color is lifted toward its own grey.
      for (final p in im) {
        final lum = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round();
        p.a = lum.clamp(0, 255);
      }
      stdout.writeln('$srcName: background -> alpha');
    }

    // Trim transparent margins.
    int minX = im.width, minY = im.height, maxX = 0, maxY = 0;
    for (int y = 0; y < im.height; y++) {
      for (int x = 0; x < im.width; x++) {
        if (im.getPixel(x, y).a > 8) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX > minX && maxY > minY) {
      im = img.copyCrop(im,
          x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);
    }

    if (im.width > maxW) {
      im = img.copyResize(im,
          width: maxW, interpolation: img.Interpolation.linear);
    }

    final out = File('${outDir.path}/$outName');
    out.writeAsBytesSync(img.encodePng(im, level: 9));
    stdout.writeln(
        '$srcName -> $outName  ${im.width}x${im.height}  ${(out.lengthSync() / 1024).round()} KB');
  }
}
