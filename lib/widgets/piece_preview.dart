import 'package:flutter/material.dart';
import '../models/block_shapes.dart';
import 'block_tile.dart';

/// Renders a [BlockPiece] at any [cellSize] (compact in the tray, full-size when dragged).
class PiecePreview extends StatelessWidget {
  const PiecePreview({
    super.key,
    required this.piece,
    required this.cellSize,
    this.cellGap = 2.0,
    this.opacity = 1.0,
  });

  final BlockPiece piece;
  final double cellSize;
  final double cellGap;
  final double opacity;

  double get totalWidth =>
      piece.shape.cols * cellSize + (piece.shape.cols - 1) * cellGap;

  double get totalHeight =>
      piece.shape.rows * cellSize + (piece.shape.rows - 1) * cellGap;

  @override
  Widget build(BuildContext context) {
    final double stride = cellSize + cellGap;

    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: totalWidth,
        height: totalHeight,
        child: Stack(
          children: [
            for (final CellCoord cell in piece.shape.cells)
              Positioned(
                left: cell.col * stride,
                top: cell.row * stride,
                child: BlockTile(
                  color: piece.color,
                  size: cellSize,
                  isBomb: piece.isBomb,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
