import 'package:image/image.dart' as img;
import 'face_box.dart';

class CropUtils {
  /// MiniFASNet input size — matches validated liveness_demo (80×80, NOT 112).
  static const int modelInputSize = 80;

  /// Crops a region from [source] centered on [bbox], expanded by [scale],
  /// then resizes to 80×80 for MiniFASNet input.
  /// scale=2.7 for V2, scale=4.0 for V1SE.
  static img.Image cropForModel(img.Image source, FaceBox bbox,
      {required double scale}) {
    final cx = bbox.centerX;
    final cy = bbox.centerY;
    final faceSize = bbox.width > bbox.height ? bbox.width : bbox.height;
    final halfCrop = faceSize * scale / 2;

    var x1 = (cx - halfCrop).round();
    var y1 = (cy - halfCrop).round();
    var x2 = (cx + halfCrop).round();
    var y2 = (cy + halfCrop).round();

    x1 = x1.clamp(0, source.width - 1);
    y1 = y1.clamp(0, source.height - 1);
    x2 = x2.clamp(x1 + 1, source.width);
    y2 = y2.clamp(y1 + 1, source.height);

    final cropped =
        img.copyCrop(source, x: x1, y: y1, width: x2 - x1, height: y2 - y1);
    return img.copyResize(cropped,
        width: modelInputSize, height: modelInputSize);
  }
}
