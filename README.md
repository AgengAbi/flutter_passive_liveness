# flutter_passive_liveness

Passive face liveness detection for Flutter using dual-model MiniFASNet (V2 + V1SE).

## Installation

Distributed as a git dependency, not on pub.dev. Pin `ref` to a tag so your
build does not shift when this package changes:

```yaml
dependencies:
  flutter_passive_liveness:
    git:
      url: https://github.com/AgengAbi/flutter_passive_liveness.git
      ref: v0.2.0
```

## Features

- Dual-model inference: V2 (scale=2.7) + V1SE (scale=4.0)
- Threshold: 0.25 per-frame, 80% majority over 2-second sliding window
- TFLite FP16 — optimized for mobile
- Validated: 99.3% accuracy, FN=0 at threshold=0.25
- No cloud calls — entirely on-device

## Usage

Inference runs in a background isolate that the package manages for you. You
only do two cheap things per frame on the main isolate: detect the face (bring
your own detector) and crop. Bring the YUV420 planes from the camera and the
face box from your detector:

```dart
final detector = PassiveLivenessDetector();
await detector.initialize();        // loads models + spawns the inference isolate

// Per camera frame (skip every 2nd–3rd frame for ~10fps):
final cropV2 = CropUtils.directCrop(
  yPlane: image.planes[0].bytes,
  uPlane: image.planes[1].bytes,
  vPlane: image.planes[2].bytes,
  width: image.width,
  height: image.height,
  yRowStride: image.planes[0].bytesPerRow,
  uvRowStride: image.planes[1].bytesPerRow,
  uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
  sensorOrientation: camera.sensorOrientation,   // 0/90/180/270
  faceLeft: face.boundingBox.left,
  faceTop: face.boundingBox.top,
  faceRight: face.boundingBox.right,
  faceBottom: face.boundingBox.bottom,
  scale: PassiveLivenessDetector.scaleV2,        // 2.7
);
final cropV1SE = CropUtils.directCrop(/* ...same, */ scale: PassiveLivenessDetector.scaleV1SE); // 4.0

final result = await detector.analyzeCrops(cropV2, cropV1SE);
// null = a frame is still being processed (dropped) — just skip it.
if (result != null && result.isLive) {
  // sustained real face → proceed with face recognition
}

detector.dispose();   // kills the isolate
```

## Threading

`analyzeCrops` sends only two small 80×80 BGR buffers across the isolate
boundary — never a full frame — so the per-frame copy cost stays tiny. The
two-model inference happens entirely inside the package's isolate; the cheap
temporal HOLD window runs on the calling isolate. No `compute()` or manual
isolate wiring needed on your side.

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

## License

The Dart source code of this package is MIT licensed (see `LICENSE`).

The bundled `.tflite` model weights are **not** MIT — they keep their original
upstream license. See `NOTICE` for the full terms, which you must comply with
when redistributing this package or an app that embeds it.
