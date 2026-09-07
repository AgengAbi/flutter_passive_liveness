## 0.2.0

- **Isolate now lives inside the package.** `initialize()` spawns a background
  inference isolate and loads the models into it (`Interpreter.fromBuffer`);
  consumers no longer wire up their own isolate.
- **New crop-based API.** `analyzeCrops(cropV2, cropV1SE)` replaces
  `analyze(img.Image, FaceBox)`. Only two 80×80 BGR buffers cross the isolate
  boundary, never a full frame.
- Added `CropUtils.directCrop(...)` — fast YUV420 → 80×80 BGR sampling that runs
  cheaply on the calling isolate (camera-package agnostic; takes raw planes).
- Extracted the temporal HOLD logic into a reusable, unit-tested `LivenessWindow`.
- `LivenessResult` now exposes `spoofAScore`, `spoofBScore`, and
  `hasSustainedSpoof` for UI/debug overlays.

## 0.1.0

- Initial release
- Dual-model MiniFASNet (V2 + V1SE) inference
- 2-second sliding window majority vote (80% threshold)
- FaceBox API — bring your own face detector
