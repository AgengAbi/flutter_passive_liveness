# flutter_passive_liveness

Passive face liveness detection for Flutter using dual-model MiniFASNet (V2 + V1SE).

## Features

- Dual-model inference: V2 (scale=2.7) + V1SE (scale=4.0)
- Threshold: 0.25 per-frame, 80% majority over 2-second sliding window
- TFLite FP16 — optimized for mobile
- Validated: 99.3% accuracy, FN=0 at threshold=0.25
- No cloud calls — entirely on-device

## Usage

```dart
final detector = PassiveLivenessDetector();
await detector.initialize();

// Call at ~10fps from a background isolate
final result = await detector.analyze(
  cameraFrame,          // img.Image — full decoded camera frame
  FaceBox(              // bounding box from your face detector (e.g. ML Kit, BlazeFace)
    left: bbox.left,
    top: bbox.top,
    right: bbox.right,
    bottom: bbox.bottom,
  ),
);

if (result.isLive) {
  // proceed with face recognition
}

// Clean up
detector.dispose();
```

## Threading

`analyze()` runs TFLite inference synchronously under the hood. Call it from a
background isolate to avoid UI jank:

```dart
// Use Dart Isolate for camera streaming (see liveness_demo for full pattern)
await compute(_runLiveness, AnalyzeArgs(frame, bbox));
```

## Research Basis

Validated on real-world dataset:
- Real: 50 frames, Print spoof: 49 frames, Display spoof: 49 frames
- Accuracy: 99.3% | FN=0 at threshold=0.25
- Models: MiniFASNetV2 + MiniFASNetV1SE (TFLite FP16)

## Acknowledgements

This package uses MiniFASNet models originally from:
[minivision-ai/Silent-Face-Anti-Spoofing](https://github.com/minivision-ai/Silent-Face-Anti-Spoofing)

Original license: Apache License 2.0

Modifications:
- Converted PyTorch (`.pth`) weights to TensorFlow Lite (`.tflite`)
- Integrated for Flutter passive liveness detection
