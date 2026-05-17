import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'model_loader.dart';
import 'crop_utils.dart';
import 'face_box.dart';
import 'liveness_result.dart';

class PassiveLivenessDetector {
  // Package-scoped asset paths — required when assets are bundled inside a package.
  static const String _v2Asset =
      'packages/flutter_passive_liveness/assets/minifasnet_v2_fp16.tflite';
  static const String _v1seAsset =
      'packages/flutter_passive_liveness/assets/minifasnet_v1se_fp16.tflite';

  static const double threshold = 0.25;
  static const double majorityRatio = 0.80;
  static const int windowDurationMs = 2000;
  static const int minWindowFrames = 5;

  /// 80×80 — matches validated liveness_demo. Do NOT change to 112.
  static const int modelInputSize = CropUtils.modelInputSize;

  Interpreter? _v2;
  Interpreter? _v1se;

  // Sliding window entries: (timestamp ms, isLive)
  final List<(int, bool)> _window = [];

  Future<void> initialize() async {
    _v2 = await ModelLoader.loadFromAsset(_v2Asset);
    _v1se = await ModelLoader.loadFromAsset(_v1seAsset);
  }

  /// Analyze a single frame. Call at ~10fps from a background isolate.
  /// [frame] is a pre-decoded img.Image (full camera frame).
  /// [faceBbox] is the detected face bounding box in [frame] pixel coords.
  /// Returns per-frame score AND window-based isLive decision.
  Future<LivenessResult> analyze(img.Image frame, FaceBox faceBbox) async {
    assert(_v2 != null && _v1se != null, 'Call initialize() first');

    final cropV2 = CropUtils.cropForModel(frame, faceBbox, scale: 2.7);
    final cropV1SE = CropUtils.cropForModel(frame, faceBbox, scale: 4.0);

    final v2Score = _runModel(_v2!, cropV2);
    final v1seScore = _runModel(_v1se!, cropV1SE);
    final combined = (v2Score + v1seScore) / 2.0;
    final frameIsLive = combined >= threshold;

    final now = DateTime.now().millisecondsSinceEpoch;
    _window.add((now, frameIsLive));
    _window.removeWhere((e) => now - e.$1 > windowDurationMs);

    final liveCount = _window.where((e) => e.$2).length;
    final isLive = _window.length >= minWindowFrames &&
        liveCount / _window.length >= majorityRatio;

    return LivenessResult(score: combined, isLive: isLive);
  }

  double _runModel(Interpreter interpreter, img.Image image) {
    // Convert img.Image to NCHW nested list [1, 3, 80, 80].
    // Channel order: BGR — MiniFASNet requires BGR, [0,255] (no /255 normalization).
    // Class index: 0=SPOOF_A, 1=REAL, 2=SPOOF_B
    final input = List.generate(
      1,
      (_) => List.generate(
        3,
        (c) => List.generate(
          modelInputSize,
          (h) => List.generate(modelInputSize, (w) {
            final pixel = image.getPixel(w, h);
            // BGR: c=0→B, c=1→G, c=2→R
            return c == 0
                ? pixel.b.toDouble()
                : c == 1
                    ? pixel.g.toDouble()
                    : pixel.r.toDouble();
          }),
        ),
      ),
    );

    final output = List.generate(1, (_) => List<double>.filled(3, 0.0));
    interpreter.run(input, output);
    return output[0][1]; // index 1 = REAL
  }

  void resetWindow() => _window.clear();

  void dispose() {
    _v2?.close();
    _v1se?.close();
  }
}
