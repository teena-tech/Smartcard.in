import 'dart:ui';
import 'package:equatable/equatable.dart';

class CardCorners extends Equatable {
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;

  const CardCorners({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  factory CardCorners.fromRect(Rect rect) {
    return CardCorners(
      topLeft: rect.topLeft,
      topRight: rect.topRight,
      bottomRight: rect.bottomRight,
      bottomLeft: rect.bottomLeft,
    );
  }

  Rect get boundingBox {
    final xs = [topLeft.dx, topRight.dx, bottomRight.dx, bottomLeft.dx];
    final ys = [topLeft.dy, topRight.dy, bottomRight.dy, bottomLeft.dy];
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  double get width => boundingBox.width;
  double get height => boundingBox.height;

  @override
  List<Object?> get props => [topLeft, topRight, bottomRight, bottomLeft];
}
