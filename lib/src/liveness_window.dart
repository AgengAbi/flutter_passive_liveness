/// Temporal HOLD window for passive liveness (anti-flicker).
///
/// MiniFASNet can misjudge a single frame (a real face dips below threshold for
/// a few milliseconds, or a spoof gets one lucky frame). Deciding per-frame
/// would flicker. This sliding window requires a *sustained* majority before
/// declaring [isLive], so one stray frame can never trigger a capture.
///
/// Defaults match the validated MiniFASNet research
/// (`model/result/catatan_riset_minifasnet_deep.md`):
/// per-frame [threshold] 0.25, at least [minFrames] (5) frames AND
/// [majorityRatio] (80%) of them real, within a [windowMs] (2000ms) window.
class LivenessWindow {
  final int windowMs;
  final int minFrames;
  final double majorityRatio;
  final double threshold;

  // (timestampMs, isRealFrame)
  final List<(int, bool)> _entries = [];

  LivenessWindow({
    this.windowMs = 2000,
    this.minFrames = 5,
    this.majorityRatio = 0.80,
    this.threshold = 0.25,
  });

  /// Record one frame's combined real-score [realScore], sampled at [nowMs].
  /// Frames older than [windowMs] relative to [nowMs] are evicted.
  void add(double realScore, int nowMs) {
    _entries.add((nowMs, realScore >= threshold));
    _entries.removeWhere((e) => nowMs - e.$1 > windowMs);
  }

  int get frameCount => _entries.length;

  double get _liveRatio {
    if (_entries.isEmpty) return 0;
    final live = _entries.where((e) => e.$2).length;
    return live / _entries.length;
  }

  /// Sustained live: enough frames collected AND a real-majority.
  bool get isLive => _entries.length >= minFrames && _liveRatio >= majorityRatio;

  /// Sustained spoof: enough frames collected AND a spoof-majority. Useful for
  /// showing a clear "not a real face" state instead of a neutral "checking".
  bool get hasSustainedSpoof =>
      _entries.length >= minFrames && _liveRatio <= (1 - majorityRatio);

  void reset() => _entries.clear();
}
