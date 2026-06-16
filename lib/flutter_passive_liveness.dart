/// Passive face liveness detection using dual-model MiniFASNet (V2 + V1SE).
///
/// Validated threshold = 0.25, 99.3% accuracy, FN = 0. Inference runs in a
/// background isolate; bring your own face detector for the bounding box.
library flutter_passive_liveness;

export 'passive_liveness_detection.dart';
