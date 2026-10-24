import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

import 'sheet_music_recognizer.dart';

/// One PDF page, rendered for recognition.
class OmrPdfPage {
  /// 0-based page number in the PDF.
  final int index;
  final int width;
  final int height;

  /// Luminance bytes, width*height (0 = black, 255 = white).
  final Uint8List gray;

  /// The same page as a PNG — shown as a preview and sent to the AI.
  final Uint8List png;

  OmrPdfPage(this.index, this.width, this.height, this.gray, this.png);
}

/// Renders one page ([pageIndex], 0-based) at [dpi]. 150 dpi gives a
/// staff-line spacing close to what the recognizer works with, while
/// keeping memory low on a tablet.
Future<OmrPdfPage?> renderPdfPage(
    Uint8List pdfBytes,
    int pageIndex, {
      double dpi = 150,
    }) async {
  await for (final raster
  in Printing.raster(pdfBytes, pages: [pageIndex], dpi: dpi)) {
    final gray = _rgbaToGray(raster.pixels, raster.width, raster.height);
    final png = await raster.toPng();
    return OmrPdfPage(pageIndex, raster.width, raster.height, gray, png);
  }
  return null;
}

/// The same page without its pixel data (keeps only the PNG preview),
/// to free memory once the page has been read.
OmrPdfPage withoutPixels(OmrPdfPage p) =>
    OmrPdfPage(p.index, p.width, p.height, Uint8List(0), p.png);

/// The longest side of a rendered page, in pixels. Enough for the
/// recognizer and the AI; much bigger would need too much memory.
const int maxRenderedSide = 2200;

/// Size of every page of the PDF, in inches (width, height). Rendered
/// at a tiny resolution (10 dpi), so it is fast and needs no memory.
Future<List<List<double>>> pdfPageSizes(Uint8List pdfBytes) async {
  final info = await Printing.info();
  if (!info.canRaster) return const [];
  const probeDpi = 10.0;
  final sizes = <List<double>>[];
  await for (final r in Printing.raster(pdfBytes, dpi: probeDpi)) {
    sizes.add([r.width / probeDpi, r.height / probeDpi]);
  }
  return sizes;
}

/// The resolution to render a page of [sizeInches] at: [preferredDpi],
/// lowered for unusually large pages (common in scanned PDFs, whose
/// pages can be declared metres wide) so the image's longest side
/// stays at most [maxRenderedSide] pixels.
double dpiForPage(List<double> sizeInches, {double preferredDpi = 150}) {
  final longest = math.max(sizeInches[0], sizeInches[1]);
  if (longest <= 0) return preferredDpi;
  return math.min(preferredDpi, maxRenderedSide / longest);
}

/// RGBA -> luminance; transparent pixels count as white paper.
Uint8List _rgbaToGray(Uint8List rgba, int width, int height) {
  final out = Uint8List(width * height);
  for (int i = 0, p = 0; i < out.length; i++, p += 4) {
    final r = rgba[p], g = rgba[p + 1], b = rgba[p + 2], a = rgba[p + 3];
    final lum = (r * 299 + g * 587 + b * 114) ~/ 1000;
    out[i] = a == 255 ? lum : (lum * a + 255 * (255 - a)) ~/ 255;
  }
  return out;
}

class _PageInput {
  final Uint8List gray;
  final int width;
  final int height;
  _PageInput(this.gray, this.width, this.height);
}

OmrPageResult _recognizeInBackground(_PageInput input) =>
    recognizeSheetMusicPage(input.gray, input.width, input.height);

/// Recognizes one page in a background isolate, so the screen stays
/// responsive.
Future<OmrPageResult> recognizePage(OmrPdfPage page) {
  return compute(
    _recognizeInBackground,
    _PageInput(page.gray, page.width, page.height),
  );
}