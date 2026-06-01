import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// ESC/POS Command Builder — Dart port of Android EscPos.kt
/// Generates raw bytes to send to thermal printer.
class EscPos {
  final _buf = BytesBuilder();

  // ── Commands (identical to Android EscPos.kt) ────────────────────────────
  static final init        = Uint8List.fromList([0x1B, 0x40]);
  static final alignLeft   = Uint8List.fromList([0x1B, 0x61, 0x00]);
  static final alignCenter = Uint8List.fromList([0x1B, 0x61, 0x01]);
  static final alignRight  = Uint8List.fromList([0x1B, 0x61, 0x02]);
  static final boldOn      = Uint8List.fromList([0x1B, 0x45, 0x01]);
  static final boldOff     = Uint8List.fromList([0x1B, 0x45, 0x00]);
  static final dblhOn      = Uint8List.fromList([0x1D, 0x21, 0x01]);
  static final dblhOff     = Uint8List.fromList([0x1D, 0x21, 0x00]);
  static final dblOn       = Uint8List.fromList([0x1D, 0x21, 0x11]);
  static final feed3       = Uint8List.fromList([0x1B, 0x64, 0x03]);
  static final feed5       = Uint8List.fromList([0x1B, 0x64, 0x05]);
  static final cut         = Uint8List.fromList([0x1D, 0x56, 0x00]);
  static final cp437       = Uint8List.fromList([0x1B, 0x74, 0x00]);

  static const int lf = 0x0A;
  static const int width58 = 32;  // chars per line on 58mm
  static const int width80 = 42;  // chars per line on 80mm

  final int charWidth;
  final int printWidthPx;

  EscPos({int paperWidthMm = 58})
      : charWidth    = paperWidthMm >= 80 ? width80 : width58,
        printWidthPx = paperWidthMm >= 80 ? 576 : 384;

  EscPos add(Uint8List data) {
    _buf.add(data);
    return this;
  }

  EscPos text(String s) {
    for (final ch in s.codeUnits) {
      _buf.addByte(ch < 256 ? ch : 63); // '?' for non-Latin
    }
    _buf.addByte(lf);
    return this;
  }

  EscPos rawText(String s) {
    for (final ch in s.codeUnits) {
      _buf.addByte(ch < 256 ? ch : 63);
    }
    return this;
  }

  EscPos byte(int b) {
    _buf.addByte(b & 0xFF);
    return this;
  }

  EscPos separator({String char = '-'}) => text(char * charWidth);

  EscPos twoCol(String left, String right) {
    final gap = charWidth - left.length - right.length;
    return text(left + ' ' * (gap > 0 ? gap : 1) + right);
  }

  EscPos addRaster(Uint8List rasterBytes) {
    _buf.add(rasterBytes);
    return this;
  }

  Uint8List build() => _buf.toBytes();
}

// ─────────────────────────────────────────────────────────────────────────────
// Raster image converter — Dart port of bitmapToRaster() from EscPos.kt
// ─────────────────────────────────────────────────────────────────────────────

/// Converts a [img.Image] to ESC/POS GS v 0 raster bytes.
/// Mirrors bitmapToRaster() in Android EscPos.kt exactly.
Uint8List imageToRaster(img.Image image, {required int targetWidthPx}) {
  // 1. Resize keeping aspect ratio
  final scale = targetWidthPx / image.width;
  final newH  = (image.height * scale).round();
  final resized = img.copyResize(image,
      width: targetWidthPx, height: newH,
      interpolation: img.Interpolation.linear);

  // 2. Convert to grayscale
  final gray = img.grayscale(resized);

  final w = gray.width;
  final h = gray.height;
  final widthBytes = (w + 7) ~/ 8;

  final result = BytesBuilder();

  // GS v 0 header (same bytes as Android)
  result.add([0x1D, 0x76, 0x30, 0x00]);
  result.add([widthBytes & 0xFF, (widthBytes >> 8) & 0xFF]); // xL xH
  result.add([h & 0xFF, (h >> 8) & 0xFF]);                   // yL yH

  // 3 & 4. Pack pixels: luminance < 128 → dot
  for (int y = 0; y < h; y++) {
    for (int bx = 0; bx < widthBytes; bx++) {
      int byteVal = 0;
      for (int bit = 0; bit < 8; bit++) {
        final x = bx * 8 + bit;
        if (x < w) {
          final pixel = gray.getPixel(x, y);
          // In image package: getPixel returns ABGR for grayscale, red channel = luminance
          final luminance = pixel.r.toInt();
          if (luminance < 128) byteVal |= (0x80 >> bit);
        }
      }
      result.addByte(byteVal);
    }
  }

  return result.toBytes();
}

/// Crop white border rows from top and bottom (mirrors Android cropWhitespace)
img.Image cropWhitespace(img.Image image, {int margin = 10}) {
  final gray = img.grayscale(image);
  final w = gray.width;
  final h = gray.height;

  int firstRow = -1, lastRow = -1;

  for (int y = 0; y < h; y++) {
    bool isWhite = true;
    for (int x = 0; x < w; x++) {
      if (gray.getPixel(x, y).r.toInt() < 250) { isWhite = false; break; }
    }
    if (!isWhite) { firstRow = y; break; }
  }

  if (firstRow < 0) return img.copyCrop(image, x: 0, y: 0, width: w, height: 1);

  for (int y = h - 1; y >= firstRow; y--) {
    bool isWhite = true;
    for (int x = 0; x < w; x++) {
      if (gray.getPixel(x, y).r.toInt() < 250) { isWhite = false; break; }
    }
    if (!isWhite) { lastRow = y; break; }
  }

  final top    = (firstRow - margin).clamp(0, h);
  final bottom = (lastRow + margin + 1).clamp(0, h);
  return img.copyCrop(image, x: 0, y: top, width: w, height: bottom - top);
}

/// Build a test receipt — mirrors Android doTestPrint()
Uint8List buildTestReceipt({int paperWidthMm = 58}) {
  final esc = EscPos(paperWidthMm: paperWidthMm);

  esc
    ..add(EscPos.init)
    ..add(EscPos.alignCenter)
    ..add(EscPos.dblhOn)
    ..add(EscPos.boldOn)
    ..text('FFit Printer')
    ..add(EscPos.dblhOff)
    ..add(EscPos.boldOff)
    ..separator()
    ..text('Test Page')
    ..text('')
    ..add(EscPos.alignLeft)
    ..text('Status   : OK - Connected')
    ..text('Driver   : ESC/POS v2')
    ..text('Paper    : ${paperWidthMm}mm Thermal')
    ..text('App      : FFit Ubuntu v1.0')
    ..separator()
    ..add(EscPos.alignCenter)
    ..text('All Systems Functional!')
    ..text('')
    ..add(EscPos.cp437)
    ..rawText('Powered by- FFIT.IO ')
    ..byte(0x03)   // ♥ in CP437 — same as Android footer
    ..byte(0x0A)
    ..add(EscPos.feed3)
    ..add(EscPos.cut);

  return esc.build();
}
