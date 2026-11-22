import 'package:flutter/material.dart';
import '../theme/snapgrid_theme.dart';

/// Available jewel colors for SnapGrid block pieces.
enum BlockColor {
  coral,
  sky,
  mint,
  amber,
  violet;

  /// Returns the main fill color for this jewel block.
  Color get fillColor {
    switch (this) {
      case BlockColor.coral:
        return SnapGridColors.coral;
      case BlockColor.sky:
        return SnapGridColors.sky;
      case BlockColor.mint:
        return SnapGridColors.mint;
      case BlockColor.amber:
        return SnapGridColors.amber;
      case BlockColor.violet:
        return SnapGridColors.violet;
    }
  }

  /// Parses a saved color name, falling back to coral if unknown.
  static BlockColor fromName(String? name) {
    return BlockColor.values.firstWhere(
      (color) => color.name == name,
      orElse: () => BlockColor.coral,
    );
  }
}

/// Immutable (row, col) coordinate inside a shape or on the 8x8 board.
@immutable
class CellCoord {
  const CellCoord(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is CellCoord && other.row == row && other.col == col);
  }

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row, $col)';
}

/// Immutable polyomino (or special Bomb Tile) shape definition.
@immutable
class BlockShape {
  const BlockShape({
    required this.id,
    required this.cells,
    required this.rows,
    required this.cols,
    this.weight = 10,
    this.isBomb = false,
  });

  final String id;
  final List<CellCoord> cells;
  final int rows;
  final int cols;
  final int weight;
  final bool isBomb;

  /// Helper factory that computes bounding-box dimensions from relative cells.
  factory BlockShape.fromCoords(
    String id,
    List<(int, int)> coords, {
    int weight = 10,
    bool isBomb = false,
  }) {
    int maxRow = 0;
    int maxCol = 0;
    final List<CellCoord> parsed = coords.map((pair) {
      if (pair.$1 > maxRow) maxRow = pair.$1;
      if (pair.$2 > maxCol) maxCol = pair.$2;
      return CellCoord(pair.$1, pair.$2);
    }).toList(growable: false);

    return BlockShape(
      id: id,
      cells: parsed,
      rows: maxRow + 1,
      cols: maxCol + 1,
      weight: weight,
      isBomb: isBomb,
    );
  }
}

/// Catalog of 19+ polyomino shapes plus the special 3x3 Combo Bomb Tile.
class BlockShapeCatalog {
  BlockShapeCatalog._();

  /// Special 1x1 Bomb Tile awarded every 10 combos.
  static final BlockShape bombTile = BlockShape.fromCoords(
    'bomb_tile',
    [(0, 0)],
    weight: 0,
    isBomb: true,
  );

  /// Standard spawnable shapes (19 distinct polyominoes).
  static final List<BlockShape> standardShapes = [
    // Single & Squares
    BlockShape.fromCoords('dot_1x1', [(0, 0)], weight: 8),
    BlockShape.fromCoords('square_2x2', [(0, 0), (0, 1), (1, 0), (1, 1)], weight: 14),
    BlockShape.fromCoords('square_3x3', [
      (0, 0), (0, 1), (0, 2),
      (1, 0), (1, 1), (1, 2),
      (2, 0), (2, 1), (2, 2),
    ], weight: 5),

    // Horizontal Bars
    BlockShape.fromCoords('bar_2h', [(0, 0), (0, 1)], weight: 14),
    BlockShape.fromCoords('bar_3h', [(0, 0), (0, 1), (0, 2)], weight: 14),
    BlockShape.fromCoords('bar_4h', [(0, 0), (0, 1), (0, 2), (0, 3)], weight: 8),
    BlockShape.fromCoords('bar_5h', [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)], weight: 4),

    // Vertical Bars
    BlockShape.fromCoords('bar_2v', [(0, 0), (1, 0)], weight: 14),
    BlockShape.fromCoords('bar_3v', [(0, 0), (1, 0), (2, 0)], weight: 14),
    BlockShape.fromCoords('bar_4v', [(0, 0), (1, 0), (2, 0), (3, 0)], weight: 8),
    BlockShape.fromCoords('bar_5v', [(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)], weight: 4),

    // Small 3-cell Corners (2x2 L)
    BlockShape.fromCoords('corner_tl', [(0, 0), (0, 1), (1, 0)], weight: 10),
    BlockShape.fromCoords('corner_tr', [(0, 0), (0, 1), (1, 1)], weight: 10),
    BlockShape.fromCoords('corner_bl', [(0, 0), (1, 0), (1, 1)], weight: 10),
    BlockShape.fromCoords('corner_br', [(0, 1), (1, 0), (1, 1)], weight: 10),

    // Big 5-cell L-Shapes (3x3)
    BlockShape.fromCoords('big_l_bl', [(0, 0), (1, 0), (2, 0), (2, 1), (2, 2)], weight: 5),
    BlockShape.fromCoords('big_l_br', [(0, 2), (1, 2), (2, 0), (2, 1), (2, 2)], weight: 5),

    // Classic 4-cell L / J / T / Z Shapes
    BlockShape.fromCoords('l_4_right', [(0, 0), (1, 0), (2, 0), (2, 1)], weight: 8),
    BlockShape.fromCoords('l_4_left', [(0, 1), (1, 1), (2, 0), (2, 1)], weight: 8),
    BlockShape.fromCoords('t_up', [(0, 1), (1, 0), (1, 1), (1, 2)], weight: 9),
    BlockShape.fromCoords('t_down', [(0, 0), (0, 1), (0, 2), (1, 1)], weight: 9),
    BlockShape.fromCoords('z_shape', [(0, 0), (0, 1), (1, 1), (1, 2)], weight: 7),
    BlockShape.fromCoords('s_shape', [(0, 1), (0, 2), (1, 0), (1, 1)], weight: 7),
  ];

  static final Map<String, BlockShape> _byId = {
    bombTile.id: bombTile,
    for (final shape in standardShapes) shape.id: shape,
  };

  /// Looks up a shape by its stable string ID.
  static BlockShape? findById(String? id) => id == null ? null : _byId[id];
}

/// A concrete piece sitting in the player's tray or Hold/Swap slot.
@immutable
class BlockPiece {
  const BlockPiece({
    required this.instanceId,
    required this.shape,
    required this.color,
  });

  final String instanceId;
  final BlockShape shape;
  final BlockColor color;

  bool get isBomb => shape.isBomb;

  Map<String, dynamic> toJson() => {
        'instanceId': instanceId,
        'shapeId': shape.id,
        'color': color.name,
      };

  static BlockPiece? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final BlockShape? shape = BlockShapeCatalog.findById(json['shapeId'] as String?);
    if (shape == null) return null;
    return BlockPiece(
      instanceId: (json['instanceId'] as String?) ?? shape.id,
      shape: shape,
      color: BlockColor.fromName(json['color'] as String?),
    );
  }
}
