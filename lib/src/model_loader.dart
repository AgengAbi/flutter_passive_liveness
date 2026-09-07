import 'package:tflite_flutter/tflite_flutter.dart';

class ModelLoader {
  /// Loads a TFLite model from a Flutter asset path.
  /// Use package-scoped path when bundled inside a package:
  /// e.g. 'packages/flutter_passive_liveness/assets/minifasnet_v2.tflite'
  static Future<Interpreter> loadFromAsset(String assetPath) async {
    final options = InterpreterOptions()..threads = 2;
    return Interpreter.fromAsset(assetPath, options: options);
  }
}
