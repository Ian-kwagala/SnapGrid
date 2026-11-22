import 'package:flutter/material.dart';
import '../logic/grid_engine.dart';
import '../models/block_shapes.dart';
import '../theme/snapgrid_theme.dart';
import '../view_models/game_view_model.dart';
import 'block_tile.dart';

/// Interactive 8x8 SnapGrid board supporting drag previews, white/gold line-clear
/// highlights, 3x3 Bomb Tile blast previews, and floating combo popups.
class GameBoard extends StatelessWidget {
  const GameBoard({
    super.key,
    required this.viewModel,
    required this.boardSize,
  });

  final GameViewModel viewModel;
  final double boardSize;

  static const double gridPadding = 8.0;
  static const double cellGap = 3.0;

  double get cellSize {
    final double inner = boardSize - gridPadding * 2;
    return (inner - cellGap * (GridEngine.gridSize - 1)) / GridEngine.gridSize;
  }

  @override
  Widget build(BuildContext context) {
    final double stride = cellSize + cellGap;
    final DragPiecePayload? activeDrag = viewModel.activeDrag;
    final PlacementPreview preview = viewModel.hoverPreview;
    final Set<CellCoord> previewCells = preview.affectedCells.toSet();
    final Set<int> clearingRows = preview.clearingRows.toSet();
    final Set<int> clearingCols = preview.clearingCols.toSet();
    final Set<CellCoord> burstCells = viewModel.burstCells.toSet();

    return SizedBox(
      width: boardSize,
      height: boardSize,
      child: DragTarget<DragPiecePayload>(
        onMove: (details) {
          final (int? r, int? c) = _resolveAnchorFromGlobalOffset(
            context,
            details.offset,
            stride,
          );
          viewModel.updateDragHover(r, c);
        },
        onLeave: (_) => viewModel.updateDragHover(null, null),
        onWillAcceptWithDetails: (details) {
          final (int? r, int? c) = _resolveAnchorFromGlobalOffset(
            context,
            details.offset,
            stride,
          );
          if (r == null || c == null) return false;
          return viewModel.hoverPreview.isValid ||
              _quickCanPlace(details.data.piece, r, c);
        },
        onAcceptWithDetails: (details) {
          final (int? r, int? c) = _resolveAnchorFromGlobalOffset(
            context,
            details.offset,
            stride,
          );
          if (r != null && c != null) {
            viewModel.dropActiveDragOnBoard(r, c);
          } else {
            viewModel.cancelDrag();
          }
        },
        builder: (context, _, _) {
          return Container(
            padding: const EdgeInsets.all(gridPadding),
            decoration: BoxDecoration(
              color: SnapGridColors.boardFrame,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SnapGridColors.boardLine, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (int r = 0; r < GridEngine.gridSize; r++)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (int c = 0; c < GridEngine.gridSize; c++)
                            _buildGridCell(
                              row: r,
                              col: c,
                              cellSize: cellSize,
                              occupiedColor: viewModel.board[r][c],
                              activeDrag: activeDrag,
                              preview: preview,
                              isInPreview: previewCells.contains(CellCoord(r, c)),
                              isLineClearCell: clearingRows.contains(r) ||
                                  clearingCols.contains(c),
                              isBurstCell: burstCells.contains(CellCoord(r, c)),
                            ),
                        ],
                      ),
                  ],
                ),
                // Floating combo / score popup over the board.
                if (viewModel.floatingPopup != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: _ComboPopupBanner(
                          key: ValueKey(viewModel.floatingPopup!.id),
                          popup: viewModel.floatingPopup!,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridCell({
    required int row,
    required int col,
    required double cellSize,
    required BlockColor? occupiedColor,
    required DragPiecePayload? activeDrag,
    required PlacementPreview preview,
    required bool isInPreview,
    required bool isLineClearCell,
    required bool isBurstCell,
  }) {
    final bool isBombPreview =
        activeDrag != null && activeDrag.piece.isBomb && isInPreview;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      width: cellSize,
      height: cellSize,
      decoration: BoxDecoration(
        color: isBombPreview
            ? SnapGridColors.bombGlow.withValues(alpha: 0.32)
            : isLineClearCell
                ? SnapGridColors.lineClearGlow.withValues(alpha: 0.25)
                : SnapGridColors.boardCell,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isBombPreview
              ? SnapGridColors.amber
              : isLineClearCell
                  ? SnapGridColors.lineClearBorder
                  : SnapGridColors.boardLine,
          width: (isLineClearCell || isBombPreview) ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (isLineClearCell)
            BoxShadow(
              color: SnapGridColors.lineClearGlow.withValues(alpha: 0.45),
              blurRadius: 8,
            ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (occupiedColor != null)
            BlockTile(
              color: occupiedColor,
              size: cellSize,
              isLineClearHighlighted: isLineClearCell,
            ),
          if (occupiedColor == null &&
              isInPreview &&
              preview.isValid &&
              activeDrag != null)
            BlockTile(
              color: activeDrag.piece.color,
              size: cellSize,
              isBomb: activeDrag.piece.isBomb,
              isGhost: true,
            ),
          if (occupiedColor == null && isBurstCell)
            _BurstFlash(key: ValueKey('burst_${viewModel.burstSeq}_${row}_$col')),
        ],
      ),
    );
  }

  (int?, int?) _resolveAnchorFromGlobalOffset(
    BuildContext context,
    Offset globalTopLeft,
    double stride,
  ) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return (null, null);

    final Offset local = box.globalToLocal(globalTopLeft);
    final double gridOrigin = gridPadding;
    final int col = ((local.dx - gridOrigin) / stride).round();
    final int row = ((local.dy - gridOrigin) / stride).round();

    if (row < 0 ||
        row >= GridEngine.gridSize ||
        col < 0 ||
        col >= GridEngine.gridSize) {
      return (null, null);
    }
    return (row, col);
  }

  bool _quickCanPlace(BlockPiece piece, int row, int col) {
    if (piece.isBomb) return true;
    for (final CellCoord c in piece.shape.cells) {
      final int r = row + c.row;
      final int cl = col + c.col;
      if (r < 0 ||
          r >= GridEngine.gridSize ||
          cl < 0 ||
          cl >= GridEngine.gridSize ||
          viewModel.board[r][cl] != null) {
        return false;
      }
    }
    return true;
  }
}

class _ComboPopupBanner extends StatefulWidget {
  const _ComboPopupBanner({super.key, required this.popup});

  final FloatingPopup popup;

  @override
  State<_ComboPopupBanner> createState() => _ComboPopupBannerState();
}

class _ComboPopupBannerState extends State<_ComboPopupBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double t = _controller.value;
        final double scale = t < 0.25 ? (0.7 + t * 1.6) : (1.1 - (t - 0.25) * 0.12);
        final double opacity = t > 0.7 ? (1.0 - (t - 0.7) / 0.3).clamp(0.0, 1.0) : 1.0;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, -t * 28),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: SnapGridColors.background.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.popup.isHighlight
                ? SnapGridColors.amber
                : SnapGridColors.sky,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (widget.popup.isHighlight
                      ? SnapGridColors.amber
                      : SnapGridColors.sky)
                  .withValues(alpha: 0.45),
              blurRadius: 16,
            ),
          ],
        ),
        child: Text(
          widget.popup.text,
          style: TextStyle(
            color: widget.popup.isHighlight
                ? SnapGridColors.lineClearGlow
                : SnapGridColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _BurstFlash extends StatefulWidget {
  const _BurstFlash({super.key});

  @override
  State<_BurstFlash> createState() => _BurstFlashState();
}

class _BurstFlashState extends State<_BurstFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final double alpha = (1.0 - _controller.value).clamp(0.0, 1.0);
        return Transform.scale(
          scale: 1.0 + _controller.value * 0.2,
          child: Container(
            decoration: BoxDecoration(
              color: SnapGridColors.lineClearGlow.withValues(alpha: alpha * 0.75),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
      },
    );
  }
}
