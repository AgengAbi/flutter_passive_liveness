/// Bounding box in image pixel coordinates.
/// Use left/top/right/bottom (not x/y/width/height) to avoid ambiguity.
class FaceBox {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const FaceBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
}
