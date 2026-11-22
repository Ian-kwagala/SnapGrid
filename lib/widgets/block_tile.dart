import 'package:flutter/material.dart';
import '../models/block_shapes.dart';
import '../theme/snapgrid_theme.dart';

/// Tactile 3D-styled jewel block tile (or glowing Bomb Tile).
class BlockTile extends StatelessWidget {
  const BlockTile({
    super.key,
    required this.color,
    required this.size,
    this.isBomb = false,
    this.isGhost = false,
    this.isLineClearHighlighted = false,
  });

  final BlockColor color;
  final double size;
  final bool isBomb;
  final bool isGhost;
  final bool isLineClearHighlighted;

  @override
  Widget build(BuildContext context) {
    final Color baseColor = isBomb ? SnapGridColors.amber : color.fillColor;
    final double radius = (size * 0.17).clamp(4.0, 8.0);

    if (isGhost) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: baseColor.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.65),
            width: 1.5,
          ),
        ),
        child: isBomb
            ? Icon(
                Icons.local_fire_department_rounded,
                size: size * 0.6,
                color: Colors.white,
              )
            : null,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isLineClearHighlighted ? SnapGridColors.lineClearGlow : baseColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: (isBomb ? SnapGridColors.bombGlow : Colors.black)
                .withValues(alpha: isBomb ? 0.55 : 0.32),
            blurRadius: isBomb ? 10 : 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: isBomb || isLineClearHighlighted
            ? Border.all(
                color: isLineClearHighlighted
                    ? SnapGridColors.lineClearBorder
                    : const Color(0xFFFFF3CD),
                width: 1.5,
              )
            : null,
      ),
      child: Stack(
        children: [
          // Subtle top highlight for a tactile 3D arcade feel.
          Positioned(
            left: size * 0.12,
            right: size * 0.12,
            top: size * 0.1,
            height: (size * 0.22).clamp(3.0, 9.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(radius * 0.5),
              ),
            ),
          ),
          if (isBomb)
            Center(
              child: Icon(
                Icons.local_fire_department_rounded,
                size: size * 0.62,
                color: const Color(0xFF3E1C00),
              ),
            ),
        ],
      ),
    );
  }
}
