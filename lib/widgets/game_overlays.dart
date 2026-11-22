import 'package:flutter/material.dart';
import '../theme/snapgrid_theme.dart';
import '../view_models/game_view_model.dart';

/// Modal pause menu allowing players to toggle sound, vibration, or restart.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.viewModel});

  final GameViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return _OverlayBackdrop(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'PAUSED',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: SnapGridColors.textPrimary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          _ToggleTile(
            icon: viewModel.soundEnabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            label: 'Sound Effects',
            value: viewModel.soundEnabled,
            onChanged: (_) => viewModel.toggleSound(),
          ),
          const SizedBox(height: 10),
          _ToggleTile(
            icon: Icons.vibration_rounded,
            label: 'Phone Vibration',
            value: viewModel.hapticsEnabled,
            onChanged: (_) => viewModel.toggleHaptics(),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: viewModel.togglePause,
              style: ElevatedButton.styleFrom(
                backgroundColor: SnapGridColors.sky,
                foregroundColor: SnapGridColors.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'RESUME',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => viewModel.restartGame(fromGameOver: false),
              style: OutlinedButton.styleFrom(
                foregroundColor: SnapGridColors.coral,
                side: const BorderSide(color: SnapGridColors.coral),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'NEW GAME',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Game Over dialog offering a 1-per-round Rewarded Ad Revive (3x3 clear)
/// and a 1-second safety delay before action buttons activate.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key, required this.viewModel});

  final GameViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final bool isNewBest =
        viewModel.score > 0 && viewModel.score >= viewModel.bestScore;
    final bool canRevive = !viewModel.hasUsedRevive;
    final bool buttonsReady = viewModel.gameOverButtonsReady;

    return _OverlayBackdrop(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'NO MORE MOVES',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: SnapGridColors.coral,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (isNewBest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: SnapGridColors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SnapGridColors.amber),
              ),
              child: const Text(
                'NEW BEST SCORE!',
                style: TextStyle(
                  color: SnapGridColors.amber,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          Text(
            '${viewModel.score}',
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              color: SnapGridColors.textPrimary,
            ),
          ),
          Text(
            'BEST: ${viewModel.bestScore}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: SnapGridColors.textMuted,
            ),
          ),
          const SizedBox(height: 22),
          if (canRevive) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: buttonsReady ? () => viewModel.reviveWithAd() : null,
                icon: const Icon(Icons.play_circle_fill_rounded),
                label: const Text(
                  'Watch Ad to Revive & Clear 3x3',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SnapGridColors.mint,
                  foregroundColor: SnapGridColors.background,
                  disabledBackgroundColor:
                      SnapGridColors.mint.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: buttonsReady
                  ? () => viewModel.restartGame(fromGameOver: true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: SnapGridColors.sky,
                foregroundColor: SnapGridColors.background,
                disabledBackgroundColor:
                    SnapGridColors.sky.withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'PLAY AGAIN',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayBackdrop extends StatelessWidget {
  const _OverlayBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.68),
      child: Center(
        child: Container(
          width: 310,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: SnapGridColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: SnapGridColors.boardLine, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: SnapGridColors.boardCell,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: SnapGridColors.sky, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: SnapGridColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: SnapGridColors.mint,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
