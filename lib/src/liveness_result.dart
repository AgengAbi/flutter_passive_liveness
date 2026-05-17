class LivenessResult {
  /// Combined liveness score = (V2_class1 + V1SE_class1) / 2.0
  /// Range: 0.0–1.0. Higher = more likely real face.
  final double score;

  /// true if score >= 0.25 AND 80% majority over 2-second sliding window
  /// (requires at least 5 frames in the window before deciding)
  final bool isLive;

  const LivenessResult({required this.score, required this.isLive});

  @override
  String toString() =>
      'LivenessResult(score: ${score.toStringAsFixed(3)}, isLive: $isLive)';
}
