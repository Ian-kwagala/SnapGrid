import 'dart:math';
import 'package:flutter/material.dart';
import '../logic/grid_engine.dart';
import '../theme/snapgrid_theme.dart';
import '../view_models/game_view_model.dart';
import '../widgets/game_board.dart';
import '../widgets/game_overlays.dart';
import '../widgets/tray_and_hold_bar.dart';

/// Main SnapGrid gameplay screen laid out top-to-bottom per the blueprint:
/// Top Bar (Best, Score, Sound/Pause) -> 8x8 Board -> Tray + Hold Slot -> Banner.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.viewModel});

  final GameViewModel viewModel;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int? _lastBannerWidth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final int widthPx = MediaQuery.sizeOf(context).width.truncate();
    if (widthPx > 0 && _lastBannerWidth != widthPx) {
      _lastBannerWidth = widthPx;
      widget.viewModel.ads.loadAdaptiveBanner(widthPx);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final GameViewModel vm = widget.viewModel;

        if (!vm.isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: SnapGridColors.sky),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _TopScoreBar(viewModel: vm),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Reserve space for combo pill + tray + 16px safe banner margin.
                          const double reservedVertical = 148.0;
                          final double maxBoardH =
                              constraints.maxHeight - reservedVertical;
                          final double maxBoardW = constraints.maxWidth - 24.0;
                          final double boardSize =
                              min(maxBoardW, maxBoardH).clamp(220.0, 440.0);
                          final double cellSize = (boardSize -
                                  GameBoard.gridPadding * 2 -
                                  GameBoard.cellGap * (GridEngine.gridSize - 1)) /
                              GridEngine.gridSize;

                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _ComboMeterPill(
                                  comboProgress: vm.comboBombProgress,
                                  comboStreak: vm.comboStreak,
                                  width: boardSize,
                                ),
                                const SizedBox(height: 8),
                                GameBoard(
                                  viewModel: vm,
                                  boardSize: boardSize,
                                ),
                                const SizedBox(height: 14),
                                TrayAndHoldBar(
                                  viewModel: vm,
                                  boardCellSize: cellSize,
                                  maxWidth: boardSize,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // 16px safe margin above the Adaptive Banner (hidden cleanly offline).
                    ValueListenableBuilder<bool>(
                      valueListenable: vm.ads.bannerReady,
                      builder: (context, ready, _) {
                        if (!ready || !vm.ads.isBannerLoaded) {
                          return const SizedBox(height: 8);
                        }
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 16),
                            Center(child: vm.ads.buildBannerWidget()),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                if (vm.isPaused && !vm.isGameOver)
                  PauseOverlay(viewModel: vm),
                if (vm.isGameOver)
                  GameOverOverlay(viewModel: vm),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopScoreBar extends StatelessWidget {
  const _TopScoreBar({required this.viewModel});

  final GameViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          // Left: Best Score Trophy
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: SnapGridColors.amber,
                  size: 24,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${viewModel.bestScore}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SnapGridColors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Center: Current Score (big bold text)
          Text(
            '${viewModel.score}',
            style: const TextStyle(
              color: SnapGridColors.textPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          // Right: Sound Toggle + Pause Gear
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: viewModel.soundEnabled ? 'Mute sound' : 'Unmute sound',
                  onPressed: viewModel.toggleSound,
                  icon: Icon(
                    viewModel.soundEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: SnapGridColors.textMuted,
                  ),
                ),
                IconButton(
                  tooltip: 'Pause / Settings',
                  onPressed: viewModel.togglePause,
                  icon: const Icon(
                    Icons.settings_rounded,
                    color: SnapGridColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComboMeterPill extends StatelessWidget {
  const _ComboMeterPill({
    required this.comboProgress,
    required this.comboStreak,
    required this.width,
  });

  final int comboProgress;
  final int comboStreak;
  final double width;

  @override
  Widget build(BuildContext context) {
    final double ratio =
        (comboProgress / GridEngine.combosPerBomb).clamp(0.0, 1.0);

    return SizedBox(
      width: width,
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 16,
            color: SnapGridColors.coral,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 7,
                backgroundColor: SnapGridColors.boardCell,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  SnapGridColors.amber,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'BOMB $comboProgress/${GridEngine.combosPerBomb}',
            style: const TextStyle(
              color: SnapGridColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (comboStreak >= 2) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: SnapGridColors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'STREAK x$comboStreak',
                style: const TextStyle(
                  color: SnapGridColors.amber,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
