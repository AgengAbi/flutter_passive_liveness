import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_passive_liveness/src/crop_utils.dart';
import 'package:flutter_passive_liveness/src/face_box.dart';
import 'package:image/image.dart' as img;

void main() {
  group('CropUtils.directCrop (YUV420 → 80×80 BGR)', () {
    // Build a synthetic, uniformly-filled YUV420 frame.
    ({Uint8List y, Uint8List u, Uint8List v}) uniformYuv(
        int w, int h, int yVal, int uVal, int vVal) {
      final y = Uint8List(w * h)..fillRange(0, w * h, yVal);
      // over-allocate U/V to keep indexing safe regardless of stride math
      final u = Uint8List(w * h)..fillRange(0, w * h, uVal);
      final v = Uint8List(w * h)..fillRange(0, w * h, vVal);
      return (y: y, u: u, v: v);
    }

    Float32List crop(
        {required int w,
        required int h,
        required int yVal,
        required int uVal,
        required int vVal,
        int orientation = 0,
        double scale = 2.7}) {
      final p = uniformYuv(w, h, yVal, uVal, vVal);
      return CropUtils.directCrop(
        yPlane: p.y,
        uPlane: p.u,
        vPlane: p.v,
        width: w,
        height: h,
        yRowStride: w,
        uvRowStride: w,
        uvPixelStride: 1,
        sensorOrientation: orientation,
        faceLeft: w * 0.3,
        faceTop: h * 0.3,
        faceRight: w * 0.7,
        faceBottom: h * 0.7,
        scale: scale,
      );
    }

    test('output is NHWC interleaved Float32List of length 80*80*3', () {
      final out = crop(w: 320, h: 240, yVal: 126, uVal: 128, vVal: 128);
      expect(out.length, 80 * 80 * 3);
    });

    test('all channel values are within [0, 255]', () {
      final out = crop(w: 320, h: 240, yVal: 200, uVal: 64, vVal: 200);
      expect(out.every((p) => p >= 0 && p <= 255), isTrue);
    });

    test('neutral gray (Y=126,U=V=128) → every channel ≈128 (BT.601)', () {
      final out = crop(w: 320, h: 240, yVal: 126, uVal: 128, vVal: 128);
      for (final p in out) {
        expect(p, closeTo(128, 1));
      }
    });

    test('deterministic: identical inputs → identical output', () {
      final a = crop(w: 320, h: 240, yVal: 150, uVal: 100, vVal: 160);
      final b = crop(w: 320, h: 240, yVal: 150, uVal: 100, vVal: 160);
      expect(a, equals(b));
    });

    test('handles every sensor orientation without throwing / out of range', () {
      for (final o in [0, 90, 180, 270]) {
        final out = crop(
            w: 320, h: 240, yVal: 130, uVal: 120, vVal: 140, orientation: o);
        expect(out.length, 80 * 80 * 3);
        expect(out.every((p) => p >= 0 && p <= 255), isTrue);
      }
    });
  });

  group('CropUtils', () {
    test('cropForModel returns 80x80 for V2 scale', () {
      final source = img.Image(width: 640, height: 480);
      const bbox = FaceBox(left: 100, top: 80, right: 300, bottom: 280);
      final cropped = CropUtils.cropForModel(source, bbox, scale: 2.7);
      expect(cropped.width, 80);
      expect(cropped.height, 80);
    });

    test('cropForModel returns 80x80 for V1SE scale', () {
      final source = img.Image(width: 640, height: 480);
      const bbox = FaceBox(left: 200, top: 100, right: 350, bottom: 250);
      final cropped = CropUtils.cropForModel(source, bbox, scale: 4.0);
      expect(cropped.width, 80);
      expect(cropped.height, 80);
    });

    test('clamps crop region to image bounds without throwing', () {
      final source = img.Image(width: 100, height: 100);
      // bbox near edge — scaled crop would exceed bounds
      const bbox = FaceBox(left: 5, top: 5, right: 55, bottom: 55);
      expect(
        () => CropUtils.cropForModel(source, bbox, scale: 4.0),
        returnsNormally,
      );
    });
  });
}
