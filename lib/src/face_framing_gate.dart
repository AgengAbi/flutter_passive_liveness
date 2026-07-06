import 'face_box.dart';

/// Where the face sits relative to the usable distance band. Lets the UI coach
/// the user ("move closer" / "move back") instead of silently refusing capture.
enum FaceDistance {
  /// No face, or an invalid image size.
  noFace,

  /// Face too small — too far from the camera (recognition needs a full face).
  tooFar,

  /// Face within the usable band.
  ok,

  /// Face too large — too close (starves MiniFASNet of the surrounding context
  /// it needs, which is how a close-up print/replay attack slips through).
  tooClose,
}

/// Decides whether a detected face is at a distance where a passive-liveness
/// verdict can be trusted.
///
/// MiniFASNet judges liveness from the face **plus its surroundings** — the two
/// crops are expanded by 2.7× and 4.0× so the models can see the tell-tale
/// border of a photo or the bezel/moiré of a screen. If the face is pushed so
/// close that it fills the frame, that context crop clamps to the image edges
/// and the border disappears, so a close-up print/replay attack can read as
/// live. This gate enforces a distance band — not too far (recognition needs a
/// full face) and not too close (liveness needs context) — so callers only run
/// a verdict when the framing is safe.
///
/// Pure geometry: no camera or model dependency, so it is cheap to call every
/// frame and trivial to unit-test.
class FaceFramingGate {
  /// Minimum face height as a fraction of the image height (too far below this).
  final double minHeightRatio;

  /// Maximum face height as a fraction of the image height (too close above
  /// this — the proximity that starves MiniFASNet of context).
  final double maxHeightRatio;

  const FaceFramingGate({
    this.minHeightRatio = 0.25,
    this.maxHeightRatio = 0.40,
  });

  /// True when [face] sits inside the usable distance band for [imageWidth] ×
  /// [imageHeight] (pixels). Caller passes upright/display-oriented dimensions
  /// so the height ratio matches what the user sees in the guide.
  bool isAtUsableDistance(FaceBox face, double imageWidth, double imageHeight) =>
      distanceOf(face, imageWidth, imageHeight) == FaceDistance.ok;

  /// Classifies the face into the distance band (tooFar / ok / tooClose), or
  /// [FaceDistance.noFace] when [imageWidth]/[imageHeight] are non-positive.
  /// The UI uses this to show a "move closer / move back" hint.
  FaceDistance distanceOf(FaceBox face, double imageWidth, double imageHeight) {
    if (imageWidth <= 0 || imageHeight <= 0) return FaceDistance.noFace;
    final ratio = face.height / imageHeight;
    if (ratio < minHeightRatio) return FaceDistance.tooFar;
    if (ratio > maxHeightRatio) return FaceDistance.tooClose;
    return FaceDistance.ok;
  }
}
