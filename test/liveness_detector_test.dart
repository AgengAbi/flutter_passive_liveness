import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Liveness decision logic', () {
    // TFLite cannot run in unit tests (no native libs), so we test the
    // score math and majority vote logic directly by mirroring the internal logic.

    double combinedScore(double v2class1, double v1seClass1) =>
        (v2class1 + v1seClass1) / 2.0;

    bool frameIsLive(double score) => score >= 0.25;

    bool windowDecision(List<bool> frames) {
      if (frames.length < 5) return false;
      final liveCount = frames.where((f) => f).length;
      return liveCount / frames.length >= 0.80;
    }

    test('combined score below threshold is not live', () {
      expect(frameIsLive(combinedScore(0.1, 0.15)), isFalse);
    });

    test('combined score at threshold is live', () {
      expect(frameIsLive(combinedScore(0.3, 0.2)), isTrue);
    });

    test('80% majority: 8 live out of 10 → window is live', () {
      final frames = List.filled(8, true) + List.filled(2, false);
      expect(windowDecision(frames), isTrue);
    });

    test('70% majority: 7 live out of 10 → window is NOT live', () {
      final frames = List.filled(7, true) + List.filled(3, false);
      expect(windowDecision(frames), isFalse);
    });

    test('fewer than 5 frames → not live (insufficient window)', () {
      final frames = [true, true, true, true];
      expect(windowDecision(frames), isFalse);
    });
  });
}
