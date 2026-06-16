import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_passive_liveness/flutter_passive_liveness.dart';

void main() {
  test('public API is exported from the package entry point', () {
    // Compile-time check that the main types are reachable via the
    // package-name library, plus a tiny runtime sanity check.
    final window = LivenessWindow();
    expect(window.frameCount, 0);
    expect(PassiveLivenessDetector.threshold, 0.25);
    expect(PassiveLivenessDetector.modelInputSize, 80);

    const result = LivenessResult(score: 0.9, isLive: true);
    expect(result.isLive, isTrue);
  });
}
