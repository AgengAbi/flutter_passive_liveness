import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_passive_liveness/src/liveness_window.dart';

void main() {
  group('LivenessWindow — temporal HOLD (anti-flicker)', () {
    test('fewer than minFrames is never live, even if all real', () {
      final w = LivenessWindow();
      for (var i = 0; i < 4; i++) {
        w.add(0.9, i * 100);
      }
      expect(w.frameCount, 4);
      expect(w.isLive, isFalse);
    });

    test('>=5 frames with >=80% real → live', () {
      final w = LivenessWindow();
      // 5 frames, all above threshold
      for (var i = 0; i < 5; i++) {
        w.add(0.9, i * 100);
      }
      expect(w.isLive, isTrue);
    });

    test('70% real over enough frames → NOT live', () {
      final w = LivenessWindow();
      // 7 real, 3 spoof out of 10 = 70%
      for (var i = 0; i < 7; i++) {
        w.add(0.9, i * 100);
      }
      for (var i = 7; i < 10; i++) {
        w.add(0.1, i * 100);
      }
      expect(w.isLive, isFalse);
    });

    test('a single lucky real frame among spoofs does NOT trigger live', () {
      final w = LivenessWindow();
      for (var i = 0; i < 9; i++) {
        w.add(0.05, i * 100); // spoof
      }
      w.add(0.95, 900); // one lucky real
      expect(w.isLive, isFalse);
      expect(w.hasSustainedSpoof, isTrue);
    });

    test('sustained spoof is detected (>=5 frames, <=20% real)', () {
      final w = LivenessWindow();
      for (var i = 0; i < 6; i++) {
        w.add(0.0, i * 100);
      }
      expect(w.hasSustainedSpoof, isTrue);
      expect(w.isLive, isFalse);
    });

    test('old frames slide out of the 2s window', () {
      final w = LivenessWindow();
      // 5 real frames at t=0..400
      for (var i = 0; i < 5; i++) {
        w.add(0.9, i * 100);
      }
      expect(w.isLive, isTrue);
      // jump 3s ahead with one new frame → old 5 evicted, only 1 remains
      w.add(0.9, 3000);
      expect(w.frameCount, 1);
      expect(w.isLive, isFalse); // below minFrames again
    });

    test('threshold boundary: exactly 0.25 counts as real', () {
      final w = LivenessWindow();
      for (var i = 0; i < 5; i++) {
        w.add(0.25, i * 100);
      }
      expect(w.isLive, isTrue);
    });

    test('reset clears the window', () {
      final w = LivenessWindow();
      for (var i = 0; i < 5; i++) {
        w.add(0.9, i * 100);
      }
      expect(w.isLive, isTrue);
      w.reset();
      expect(w.frameCount, 0);
      expect(w.isLive, isFalse);
    });
  });
}
