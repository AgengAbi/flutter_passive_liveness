import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'face_box.dart';

class CropUtils {
  /// MiniFASNet input size — matches validated liveness_demo (80×80, NOT 112).
  static const int modelInputSize = 80;

  /// Samples an [modelInputSize]×[modelInputSize] crop DIRECTLY from raw YUV420
  /// planes — expanded by [scale] around the face box — without decoding the
  /// whole frame. This is the fast path proven in `model/liveness_demo`
  /// (~6.4k samples vs ~920k for a full decode), so it stays cheap on the main
  /// isolate while the heavy model inference is offloaded elsewhere.
  ///
  /// Returns an NHWC interleaved [Float32List] of length `size*size*3` in **BGR**
  /// order, range **[0, 255]** — NOT divided by 255 (MiniFASNet `to_tensor()`
  /// expects raw [0,255]). The inference side reshapes this to NCHW.
  ///
  /// [faceLeft]/[faceTop]/[faceRight]/[faceBottom] are in the UPRIGHT (display)
  /// coordinate space produced by the face detector. [sensorOrientation]
  /// (0/90/180/270) maps those back onto the raw sensor planes. Stays
  /// camera-package agnostic by taking raw plane bytes + strides directly.
  static Float32List directCrop({
    required Uint8List yPlane,
    required Uint8List uPlane,
    required Uint8List vPlane,
    required int width,
    required int height,
    required int yRowStride,
    required int uvRowStride,
    required int uvPixelStride,
    required int sensorOrientation,
    required double faceLeft,
    required double faceTop,
    required double faceRight,
    required double faceBottom,
    required double scale,
  }) {
    const int target = modelInputSize;

    final double cx = (faceLeft + faceRight) / 2;
    final double cy = (faceTop + faceBottom) / 2;
    final double faceW = faceRight - faceLeft;
    final double faceH = faceBottom - faceTop;
    final double faceSize = faceW > faceH ? faceW : faceH;
    final double halfCrop = faceSize * scale / 2;
    final double step = 2 * halfCrop / target;

    final out = Float32List(target * target * 3);
    int idx = 0;

    for (int ty = 0; ty < target; ty++) {
      final double dispY = cy - halfCrop + (ty + 0.5) * step;
      for (int tx = 0; tx < target; tx++) {
        final double dispX = cx - halfCrop + (tx + 0.5) * step;

        int ox, oy;
        switch (sensorOrientation) {
          case 90:
            ox = dispY.round().clamp(0, width - 1);
            oy = (height - 1 - dispX.round()).clamp(0, height - 1);
          case 180:
            ox = (width - 1 - dispX.round()).clamp(0, width - 1);
            oy = (height - 1 - dispY.round()).clamp(0, height - 1);
          case 270:
            ox = (width - 1 - dispY.round()).clamp(0, width - 1);
            oy = dispX.round().clamp(0, height - 1);
          default:
            ox = dispX.round().clamp(0, width - 1);
            oy = dispY.round().clamp(0, height - 1);
        }

        final int yVal = yPlane[oy * yRowStride + ox] & 0xFF;
        final int uvIdx = (oy ~/ 2) * uvRowStride + (ox ~/ 2) * uvPixelStride;
        final int uVal = uPlane[uvIdx] & 0xFF;
        final int vVal = vPlane[uvIdx] & 0xFF;

        // BT.601 YUV → RGB, integer arithmetic (matches validated demo).
        final int c = yVal - 16;
        final int d = uVal - 128;
        final int e = vVal - 128;
        final int r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
        final int g =
            ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
        final int b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);

        // BGR order, [0,255] — no /255.
        out[idx++] = b.toDouble();
        out[idx++] = g.toDouble();
        out[idx++] = r.toDouble();
      }
    }
    return out;
  }

  /// Crops a region from [source] centered on [bbox], expanded by [scale],
  /// then resizes to 80×80 for MiniFASNet input.
  /// scale=2.7 for V2, scale=4.0 for V1SE.
  static img.Image cropForModel(img.Image source, FaceBox bbox,
      {required double scale}) {
    final cx = bbox.centerX;
    final cy = bbox.centerY;
    final faceSize = bbox.width > bbox.height ? bbox.width : bbox.height;
    final halfCrop = faceSize * scale / 2;

    var x1 = (cx - halfCrop).round();
    var y1 = (cy - halfCrop).round();
    var x2 = (cx + halfCrop).round();
    var y2 = (cy + halfCrop).round();

    x1 = x1.clamp(0, source.width - 1);
    y1 = y1.clamp(0, source.height - 1);
    x2 = x2.clamp(x1 + 1, source.width);
    y2 = y2.clamp(y1 + 1, source.height);

    final cropped =
        img.copyCrop(source, x: x1, y: y1, width: x2 - x1, height: y2 - y1);
    return img.copyResize(cropped,
        width: modelInputSize, height: modelInputSize);
  }
}
