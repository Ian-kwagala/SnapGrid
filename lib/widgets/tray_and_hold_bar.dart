import 'package:flutter/material.dart';
import '../models/block_shapes.dart';
import '../theme/snapgrid_theme.dart';
import '../view_models/game_view_model.dart';
import 'piece_preview.dart';

/// Bottom tray housing the 3 playable pieces on the left/center and the
/// Hold / Swap Bank Slot(s) on the right.
class TrayAndHoldBar extends StatelessWidget {
  const TrayAndHoldBar({
    super.key,
    required this.viewModel,
    required this.boardCellSize,
    required this.maxWidth,
  });

  final GameViewModel viewModel;
  final double boardCellSize;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final double trayCellSize = (boardCellSize * 0.48).clamp(13.0, 20.0);
    final double holdCellSize = (boardCellSize * 0.42).clamp(11.0, 17.0);

    return SizedBox(
      width: maxWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 3-Piece Drag Tray (left / center)
          Expanded(
            flex: 3,
            child: Container(
              height: 98,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: SnapGridColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SnapGridColors.boardLine),
              ),
              child: Row(
                children: [
                  for (int i = 0; i < 3; i++)
                    Expanded(
                      child: _buildDraggablePieceSlot(
                        originType: DragOriginType.tray,
                        index: i,
                        piece: viewModel.trayPieces[i],
                        previewCellSize: trayCellSize,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Hold / Swap Bank Box (right)
          Expanded(
            flex: 1,
            child: _HoldBankColumn(
              viewModel: viewModel,
              holdCellSize: holdCellSize,
              buildDraggablePiece: (index, piece) => _buildDraggablePieceSlot(
                originType: DragOriginType.hold,
                index: index,
                piece: piece,
                previewCellSize: holdCellSize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggablePieceSlot({
    required DragOriginType originType,
    required int index,
    required BlockPiece? piece,
    required double previewCellSize,
  }) {
    if (piece == null) {
      return const SizedBox.expand();
    }

    final DragPiecePayload payload = DragPiecePayload(
      originType: originType,
      index: index,
      piece: piece,
    );

    // Feedback matches exact 8x8 board scale and lifts upward above the thumb.
    final PiecePreview dragFeedback = PiecePreview(
      piece: piece,
      cellSize: boardCellSize,
      cellGap: 3.0,
    );

    final double feedbackW = dragFeedback.totalWidth;
    final double feedbackH = dragFeedback.totalHeight;

    return Center(
      child: Draggable<DragPiecePayload>(
        data: payload,
        maxSimultaneousDrags: viewModel.isPaused || viewModel.isGameOver ? 0 : 1,
        // Anchor near bottom-center + 44px lift so the finger never blocks view.
        dragAnchorStrategy: (_, _, _) => Offset(
          feedbackW / 2,
          feedbackH + 44.0,
        ),
        onDragStarted: () => viewModel.startDrag(payload),
        onDraggableCanceled: (_, _) => viewModel.cancelDrag(),
        onDragEnd: (_) => viewModel.cancelDrag(),
        feedback: Material(
          color: Colors.transparent,
          child: dragFeedback,
        ),
        childWhenDragging: Opacity(
          opacity: 0.18,
          child: PiecePreview(piece: piece, cellSize: previewCellSize),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: PiecePreview(piece: piece, cellSize: previewCellSize),
          ),
        ),
      ),
    );
  }
}

class _HoldBankColumn extends StatelessWidget {
  const _HoldBankColumn({
    required this.viewModel,
    required this.holdCellSize,
    required this.buildDraggablePiece,
  });

  final GameViewModel viewModel;
  final double holdCellSize;
  final Widget Function(int index, BlockPiece? piece) buildDraggablePiece;

  @override
  Widget build(BuildContext context) {
    final bool secondUnlocked = viewModel.hasSecondHoldSlot;

    return SizedBox(
      height: 98,
      child: Column(
        children: [
          // Free Hold / Swap Slot #1
          Expanded(
            child: _HoldSlotTarget(
              holdIndex: 0,
              label: 'HOLD',
              piece: viewModel.holdSlots[0],
              viewModel: viewModel,
              child: buildDraggablePiece(0, viewModel.holdSlots[0]),
            ),
          ),
          const SizedBox(height: 6),
          // 2nd Hold Slot (Locked behind Rewarded Ad until unlocked this round)
          Expanded(
            child: secondUnlocked
                ? _HoldSlotTarget(
                    holdIndex: 1,
                    label: 'HOLD 2',
                    piece: viewModel.holdSlots[1],
                    viewModel: viewModel,
                    child: buildDraggablePiece(1, viewModel.holdSlots[1]),
                  )
                : InkWell(
                    onTap: viewModel.isPaused || viewModel.isGameOver
                        ? null
                        : () => viewModel.unlockSecondHoldSlotWithAd(),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: SnapGridColors.surface.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: SnapGridColors.amber.withValues(alpha: 0.45),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_circle_fill_rounded,
                            size: 14,
                            color: SnapGridColors.amber,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '+SLOT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: SnapGridColors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HoldSlotTarget extends StatelessWidget {
  const _HoldSlotTarget({
    required this.holdIndex,
    required this.label,
    required this.piece,
    required this.viewModel,
    required this.child,
  });

  final int holdIndex;
  final String label;
  final BlockPiece? piece;
  final GameViewModel viewModel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragTarget<DragPiecePayload>(
      onWillAcceptWithDetails: (details) =>
          details.data.originType == DragOriginType.tray,
      onAcceptWithDetails: (details) {
        viewModel.holdOrSwapTrayPiece(
          details.data.index,
          holdIndex: holdIndex,
        );
      },
      builder: (context, candidateData, _) {
        final bool hovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          decoration: BoxDecoration(
            color: hovering
                ? SnapGridColors.sky.withValues(alpha: 0.22)
                : SnapGridColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hovering
                  ? SnapGridColors.sky
                  : SnapGridColors.boardLine,
              width: hovering ? 1.8 : 1.0,
            ),
          ),
          child: piece == null
              ? Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: SnapGridColors.textMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(3),
                  child: child,
                ),
        );
      },
    );
  }
}
