/// Result of one passive-liveness analysis.
class LivenessResult {
  /// Combined REAL score = (V2_class1 + V1SE_class1) / 2.0. Range 0.0–1.0.
  /// Higher = more likely a real face. Per-frame "real" if >= 0.25.
  final double score;

  /// Combined spoof scores (class0 = print-type, class2 = display-type).
  /// Exposed mainly for debugging/telemetry overlays.
  final double spoofAScore;
  final double spoofBScore;

  /// Sustained-live decision from the temporal HOLD window:
  /// >=5 frames AND >=80% real over the 2-second sliding window.
  final bool isLive;

  /// Sustained-spoof decision (>=5 frames AND <=20% real). Lets the UI show a
  /// confident "not a real face" state instead of a neutral "checking".
  final bool hasSustainedSpoof;

  const LivenessResult({
    required this.score,
    this.spoofAScore = 0.0,
    this.spoofBScore = 0.0,
    required this.isLive,
    this.hasSustainedSpoof = false,
  });

  @override
  String toString() =>
      'LivenessResult(real: ${score.toStringAsFixed(3)}, '
      'isLive: $isLive, spoof: $hasSustainedSpoof)';
}
