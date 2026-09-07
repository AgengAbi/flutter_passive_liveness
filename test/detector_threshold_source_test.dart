import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_passive_liveness/passive_liveness_detection.dart';

void main() {
  test('detector defaults to the validated 0.25 threshold', () {
    expect(PassiveLivenessDetector().threshold, 0.25);
  });

  test('detector reports the window threshold (single source of truth)', () {
    final d = PassiveLivenessDetector(window: LivenessWindow(threshold: 0.30));
    expect(d.threshold, 0.30);
  });
}
