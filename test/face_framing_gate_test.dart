import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_passive_liveness/passive_liveness_detection.dart';

void main() {
  const gate = FaceFramingGate();
  const imageW = 480.0;
  const imageH = 640.0;

  // A centred face whose height is [heightRatio] of the image height.
  FaceBox faceOfHeight(double heightRatio) {
    final h = heightRatio * imageH;
    final w = h * 0.8;
    final cx = imageW / 2;
    final cy = imageH * 0.45;
    return FaceBox(
        left: cx - w / 2, top: cy - h / 2, right: cx + w / 2, bottom: cy + h / 2);
  }

  test('face at an ideal distance is usable', () {
    expect(gate.isAtUsableDistance(faceOfHeight(0.38), imageW, imageH), isTrue);
  });

  test('face too far (small) is not usable', () {
    expect(gate.isAtUsableDistance(faceOfHeight(0.20), imageW, imageH), isFalse);
  });

  test('face too close (fills the frame) is not usable — keeps liveness context',
      () {
    // When the face fills the frame, MiniFASNet's context crop (scale 2.7/4.0)
    // clamps to the image edges and loses the paper edge / screen bezel, so a
    // close-up print/replay attack reads as live. Refusing this proximity keeps
    // the surrounding context the models rely on.
    expect(gate.isAtUsableDistance(faceOfHeight(0.85), imageW, imageH), isFalse);
  });

  test('non-positive image size is never usable', () {
    expect(gate.isAtUsableDistance(faceOfHeight(0.55), 0, 0), isFalse);
  });

  group('distanceOf — 3-state feedback for the UI', () {
    test('reports tooFar below the min band', () {
      expect(gate.distanceOf(faceOfHeight(0.20), imageW, imageH),
          FaceDistance.tooFar);
    });

    test('reports ok inside the band', () {
      expect(gate.distanceOf(faceOfHeight(0.38), imageW, imageH),
          FaceDistance.ok);
    });

    test('reports tooClose just above the max band (0.50)', () {
      expect(gate.distanceOf(faceOfHeight(0.60), imageW, imageH),
          FaceDistance.tooClose);
    });

    test('reports tooFar just below the min band (0.25)', () {
      expect(gate.distanceOf(faceOfHeight(0.22), imageW, imageH),
          FaceDistance.tooFar);
    });

    test('reports noFace for a non-positive image size', () {
      expect(gate.distanceOf(faceOfHeight(0.55), 0, 0), FaceDistance.noFace);
    });
  });
}
