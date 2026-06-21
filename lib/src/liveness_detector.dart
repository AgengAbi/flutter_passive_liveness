import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'crop_utils.dart';
import 'liveness_result.dart';
import 'liveness_window.dart';

/// On-device passive face-liveness detector (dual-model MiniFASNet V2 + V1SE).
///
/// The heavy part — running two TFLite models per frame — happens in a
/// dedicated background [Isolate] so the camera preview and UI never jank.
/// The cheap part — the temporal HOLD window — stays on the calling isolate.
///
/// Threading model:
///  1. [initialize] loads the bundled `.tflite` bytes (on the calling isolate,
///     so `rootBundle` works), then spawns the inference isolate and hands it
///     the bytes (`Interpreter.fromBuffer` — no `RootIsolateToken` dance).
///  2. The caller crops each frame with [CropUtils.directCrop] (cheap, main
///     isolate) and calls [analyzeCrops] with the two 80×80 BGR buffers. Only
///     those small buffers cross the isolate boundary — never a full frame.
///  3. The isolate runs both models, combines scores, and returns the raw
///     real/spoof scores. [analyzeCrops] feeds that into the [LivenessWindow]
///     and returns a [LivenessResult] with the sustained [LivenessResult.isLive]
///     decision.
class PassiveLivenessDetector {
  // Full-precision (FP32) models — these are the variants the research was
  // validated on (threshold 0.25, FN=0, FP=1). The FP16 variants degrade
  // spoof discrimination (prints score mid-range instead of low), so they are
  // intentionally NOT used. See docs/SPEC_CHANGES.md (2026-06-21).
  static const String _v2Asset =
      'packages/flutter_passive_liveness/assets/minifasnet_v2.tflite';
  static const String _v1seAsset =
      'packages/flutter_passive_liveness/assets/minifasnet_v1se.tflite';

  /// Per-frame REAL-score threshold (validated 0.25).
  static const double threshold = 0.25;

  /// MiniFASNet input size (80×80).
  static const int modelInputSize = CropUtils.modelInputSize;

  /// Crop expansion factors per model (from the official model filenames).
  static const double scaleV2 = 2.7;
  static const double scaleV1SE = 4.0;

  final LivenessWindow _window;

  Isolate? _isolate;
  SendPort? _toIsolate;
  ReceivePort? _fromIsolate;
  StreamSubscription<dynamic>? _sub;
  Completer<_RawScore>? _pending;
  bool _busy = false;

  PassiveLivenessDetector({LivenessWindow? window})
      : _window = window ?? LivenessWindow();

  /// True once [initialize] has finished and the isolate is ready for frames.
  bool get isReady => _toIsolate != null;

  Future<void> initialize() async {
    final v2Bytes = (await rootBundle.load(_v2Asset)).buffer.asUint8List();
    final v1seBytes = (await rootBundle.load(_v1seAsset)).buffer.asUint8List();

    _fromIsolate = ReceivePort();
    final ready = Completer<void>();

    _isolate = await Isolate.spawn(
      _isolateEntry,
      _InitMsg(_fromIsolate!.sendPort, v2Bytes, v1seBytes),
    );

    _sub = _fromIsolate!.listen((msg) {
      if (msg is SendPort) {
        _toIsolate = msg;
        ready.complete();
      } else if (msg is _RawScore) {
        _busy = false;
        _pending?.complete(msg);
        _pending = null;
      }
    });

    await ready.future;
  }

  /// Analyze one frame from its two pre-computed crops (see
  /// [CropUtils.directCrop]). [cropV2] uses [scaleV2], [cropV1SE] uses
  /// [scaleV1SE]; both are NHWC BGR [0,255] of length `80*80*3`.
  ///
  /// Returns null if the isolate isn't ready or a previous frame is still being
  /// processed — i.e. frames are dropped rather than queued, so the pipeline
  /// never backs up. Pass [nowMs] in tests for deterministic window timing.
  Future<LivenessResult?> analyzeCrops(
    Float32List cropV2,
    Float32List cropV1SE, {
    int? nowMs,
  }) async {
    if (!isReady || _busy) return null;
    _busy = true;
    final completer = Completer<_RawScore>();
    _pending = completer;
    _toIsolate!.send(<Float32List>[cropV2, cropV1SE]);

    final raw = await completer.future;
    final t = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    _window.add(raw.real, t);

    return LivenessResult(
      score: raw.real,
      spoofAScore: raw.spoofA,
      spoofBScore: raw.spoofB,
      isLive: _window.isLive,
      hasSustainedSpoof: _window.hasSustainedSpoof,
    );
  }

  /// Clear the HOLD window (e.g. when the face leaves the frame or a new
  /// attempt starts).
  void reset() => _window.reset();

  void dispose() {
    _sub?.cancel();
    _isolate?.kill(priority: Isolate.immediate);
    _fromIsolate?.close();
    _toIsolate = null;
    _isolate = null;
    _pending = null;
    _busy = false;
  }
}

// ── Isolate side ─────────────────────────────────────────────────────────────

class _InitMsg {
  final SendPort sendPort;
  final Uint8List v2Bytes;
  final Uint8List v1seBytes;
  const _InitMsg(this.sendPort, this.v2Bytes, this.v1seBytes);
}

class _RawScore {
  final double real;
  final double spoofA;
  final double spoofB;
  const _RawScore(this.real, this.spoofA, this.spoofB);
}

void _isolateEntry(_InitMsg init) async {
  final port = ReceivePort();
  init.sendPort.send(port.sendPort);

  final v2 = Interpreter.fromBuffer(init.v2Bytes);
  final v1se = Interpreter.fromBuffer(init.v1seBytes);
  v2.allocateTensors();
  v1se.allocateTensors();

  await for (final msg in port) {
    if (msg is List && msg.length == 2) {
      final cropV2 = msg[0] as Float32List;
      final cropV1SE = msg[1] as Float32List;

      final a = _runModel(v2, cropV2);
      final b = _runModel(v1se, cropV1SE);

      // Combine = per-class average of the two models' RAW outputs.
      // NOTE: these are raw class scores (logits), NOT 0-1 softmax
      // probabilities — in practice spoofs land negative and real faces land
      // above ~1, with the validated threshold (0.25) sitting in the gap.
      // Class mapping: [0]=SPOOF_A, [1]=REAL, [2]=SPOOF_B.
      init.sendPort.send(_RawScore(
        (a[1] + b[1]) / 2.0,
        (a[0] + b[0]) / 2.0,
        (a[2] + b[2]) / 2.0,
      ));
    }
  }
}

/// Reshape an NHWC interleaved [80*80*3] buffer into the NCHW [1,3,80,80]
/// nested list the TFLite models expect, then run inference.
List<double> _runModel(Interpreter interp, Float32List nhwc) {
  const n = PassiveLivenessDetector.modelInputSize;
  final input = List.generate(
    1,
    (_) => List.generate(
      3,
      (c) => List.generate(
        n,
        (h) => List.generate(n, (w) => nhwc[(h * n + w) * 3 + c]),
      ),
    ),
  );
  final output = List.generate(1, (_) => List<double>.filled(3, 0.0));
  interp.run(input, output);
  return output[0];
}
