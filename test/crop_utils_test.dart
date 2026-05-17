import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_passive_liveness/src/crop_utils.dart';
import 'package:flutter_passive_liveness/src/face_box.dart';
import 'package:image/image.dart' as img;

void main() {
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
