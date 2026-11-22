import 'dart:async';
import 'package:flutter/foundation.dart';
import '../logic/grid_engine.dart';
import '../models/block_shapes.dart';
import '../services/ad_service.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';

/// Identifies where a dragged piece came from (either the 3-piece tray or Hold slot).
enum DragOriginType { tray, hold }

@immutable
class DragPiecePayload {
  const DragPiecePayload({
    required this.originType,
    required this.index,
    required this.piece,
  });

  final DragOriginType originType;
  final int index;
  final BlockPiece piece;
}

/// Ephemeral floating text shown over the board for combos and bomb events.
@immutable
class FloatingPopup {
  const FloatingPopup({
    required this.id,
    required this.text,
    this.isHighlight = false,
  });

  final int id;
  final String text;
  final bool isHighlight;
}

/// ViewModel connecting [GridEngine] to storage, audio, haptics, ads, and UI state.
class GameViewModel extends ChangeNotifier {
  GameViewModel({
    required this._engine,
    required this._storage,
    required this._sound,
    required this._haptics,
    required this._ads,
  });

  final GridEngine _engine;
  final StorageService _storage;
  final SoundService _sound;
  final HapticService _haptics;
  final AdService _ads;

  bool _isInitialized = false;
  bool _isPaused = false;
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  bool _gameOverButtonsReady = false;
  int _gamesFinishedCount = 0;

  // Active drag state
  DragPiecePayload? _activeDrag;
  int? _hoverAnchorRow;
  int? _hoverAnchorCol;
  PlacementPreview _hoverPreview = PlacementPreview.invalid;

  // Visual feedback state
  int _popupSeq = 0;
  FloatingPopup? _floatingPopup;
  Timer? _popupTimer;
  Timer? _gameOverDelayTimer;
  List<CellCoord> _burstCells = const [];
  int _burstSeq = 0;

  // Getters for the UI
  bool get isInitialized => _isInitialized;
  bool get isPaused => _isPaused;
  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get gameOverButtonsReady => _gameOverButtonsReady;

  List<List<BlockColor?>> get board => _engine.board;
  List<BlockPiece?> get trayPieces => _engine.trayPieces;
  List<BlockPiece?> get holdSlots => _engine.holdSlots;
  int get score => _engine.score;
  int get bestScore => _engine.bestScore;
  int get comboStreak => _engine.comboStreak;
  int get comboBombProgress => _engine.comboBombProgress;
  bool get hasSecondHoldSlot => _engine.hasSecondHoldSlot;
  bool get hasUsedRevive => _engine.hasUsedRevive;
  bool get isGameOver => _engine.isGameOver;

  DragPiecePayload? get activeDrag => _activeDrag;
  int? get hoverAnchorRow => _hoverAnchorRow;
  int? get hoverAnchorCol => _hoverAnchorCol;
  PlacementPreview get hoverPreview => _hoverPreview;
  FloatingPopup? get floatingPopup => _floatingPopup;
  List<CellCoord> get burstCells => _burstCells;
  int get burstSeq => _burstSeq;
  AdService get ads => _ads;

  /// Loads saved preferences, best score, and any active offline game.
  Future<void> init() async {
    if (_isInitialized) return;

    await _storage.init();
    _soundEnabled = await _storage.isSoundEnabled();
    _hapticsEnabled = await _storage.isHapticsEnabled();
    _gamesFinishedCount = await _storage.getGamesFinishedCount();
    final int savedBest = await _storage.getBestScore();

    _sound.enabled = _soundEnabled;
    _haptics.enabled = _hapticsEnabled;
    await _sound.init();

    _engine.updateBestScore(savedBest);

    final Map<String, dynamic>? savedGame = await _storage.loadSavedGame();
    if (savedGame != null) {
      final bool restored = _engine.restoreFromJson(savedGame);
      if (!restored) {
        _engine.resetGame(bestScore: savedBest);
      }
    }

    if (_engine.isGameOver) {
      _scheduleGameOverSafetyDelay();
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Called when the player starts dragging a piece from the tray or Hold slot.
  void startDrag(DragPiecePayload payload) {
    _activeDrag = payload;
    _hoverAnchorRow = null;
    _hoverAnchorCol = null;
    _hoverPreview = PlacementPreview.invalid;
    unawaited(_sound.playPickup());
    unawaited(_haptics.pickup());
    notifyListeners();
  }

  /// Updates the hovered grid anchor while dragging over the 8x8 board.
  void updateDragHover(int? anchorRow, int? anchorCol) {
    final DragPiecePayload? drag = _activeDrag;
    if (drag == null) return;

    if (anchorRow == null || anchorCol == null) {
      if (_hoverAnchorRow != null || _hoverAnchorCol != null) {
        _hoverAnchorRow = null;
        _hoverAnchorCol = null;
        _hoverPreview = PlacementPreview.invalid;
        notifyListeners();
      }
      return;
    }

    if (_hoverAnchorRow == anchorRow && _hoverAnchorCol == anchorCol) {
      return;
    }

    _hoverAnchorRow = anchorRow;
    _hoverAnchorCol = anchorCol;
    _hoverPreview = _engine.previewPlacement(
      drag.piece.shape,
      anchorRow,
      anchorCol,
    );
    notifyListeners();
  }

  /// Clears drag state if the piece was dropped outside valid targets.
  void cancelDrag() {
    if (_activeDrag == null && _hoverAnchorRow == null) return;
    _activeDrag = null;
    _hoverAnchorRow = null;
    _hoverAnchorCol = null;
    _hoverPreview = PlacementPreview.invalid;
    notifyListeners();
  }

  /// Attempts to drop the dragged piece onto the 8x8 board.
  Future<bool> dropActiveDragOnBoard(int anchorRow, int anchorCol) async {
    final DragPiecePayload? drag = _activeDrag;
    _activeDrag = null;
    _hoverAnchorRow = null;
    _hoverAnchorCol = null;
    _hoverPreview = PlacementPreview.invalid;

    if (drag == null || _isPaused) {
      notifyListeners();
      return false;
    }

    final PlacementResult result = drag.originType == DragOriginType.tray
        ? _engine.placeTrayPiece(drag.index, anchorRow, anchorCol)
        : _engine.placeHeldPiece(drag.index, anchorRow, anchorCol);

    if (!result.success) {
      notifyListeners();
      return false;
    }

    await _handlePlacementFeedback(result);
    await _persistState();
    notifyListeners();
    return true;
  }

  /// Parks or swaps a tray piece into [holdIndex] (0 or 1).
  Future<bool> holdOrSwapTrayPiece(int trayIndex, {int holdIndex = 0}) async {
    _activeDrag = null;
    _hoverAnchorRow = null;
    _hoverAnchorCol = null;
    _hoverPreview = PlacementPreview.invalid;

    if (_isPaused) {
      notifyListeners();
      return false;
    }

    final bool swapped = _engine.holdOrSwapTrayPiece(
      trayIndex,
      holdIndex: holdIndex,
    );
    if (!swapped) {
      notifyListeners();
      return false;
    }

    unawaited(_sound.playPlace());
    unawaited(_haptics.pickup());

    if (_engine.isGameOver) {
      await _onGameOverReached();
    }

    await _persistState();
    notifyListeners();
    return true;
  }

  /// Toggles pause overlay.
  void togglePause() {
    if (_engine.isGameOver) return;
    _isPaused = !_isPaused;
    notifyListeners();
  }

  void setPaused(bool paused) {
    if (_isPaused == paused) return;
    _isPaused = paused;
    notifyListeners();
  }

  /// Toggles sound effects on/off and persists the setting.
  Future<void> toggleSound() async {
    _soundEnabled = !_soundEnabled;
    _sound.enabled = _soundEnabled;
    await _storage.setSoundEnabled(_soundEnabled);
    notifyListeners();
  }

  /// Toggles phone vibration on/off and persists the setting.
  Future<void> toggleHaptics() async {
    _hapticsEnabled = !_hapticsEnabled;
    _haptics.enabled = _hapticsEnabled;
    await _storage.setHapticsEnabled(_hapticsEnabled);
    notifyListeners();
  }

  /// Watches a Rewarded Ad to unlock a temporary 2nd Hold Slot for this round.
  Future<bool> unlockSecondHoldSlotWithAd() async {
    if (_engine.hasSecondHoldSlot) return true;
    final bool rewarded = await _ads.showRewardedAd();
    if (!rewarded) return false;

    _engine.unlockSecondHoldSlot();
    _showPopup('2ND HOLD SLOT UNLOCKED!', highlight: true);
    await _persistState();
    notifyListeners();
    return true;
  }

  /// Watches a Rewarded Ad on Game Over to clear a 3x3 area and continue (1 per round).
  Future<bool> reviveWithAd() async {
    if (!_engine.isGameOver || _engine.hasUsedRevive) return false;
    final bool rewarded = await _ads.showRewardedAd();
    if (!rewarded) return false;

    final List<CellCoord> cleared = _engine.reviveWithBombClear();
    _burstCells = cleared;
    _burstSeq++;
    _gameOverDelayTimer?.cancel();
    _gameOverButtonsReady = false;

    unawaited(_sound.playBomb());
    unawaited(_haptics.bomb());
    _showPopup('REVIVED! 3x3 CLEARED', highlight: true);

    await _persistState();
    notifyListeners();
    return true;
  }

  /// Starts a new round. Shows an Interstitial Ad every 2 finished games.
  Future<void> restartGame({bool fromGameOver = false}) async {
    if (fromGameOver) {
      await _ads.showInterstitialIfEligible(
        gamesFinishedCount: _gamesFinishedCount,
      );
    }

    _gameOverDelayTimer?.cancel();
    _gameOverButtonsReady = false;
    _isPaused = false;
    _activeDrag = null;
    _hoverAnchorRow = null;
    _hoverAnchorCol = null;
    _hoverPreview = PlacementPreview.invalid;
    _floatingPopup = null;
    _burstCells = const [];

    _engine.resetGame();
    await _persistState();
    notifyListeners();
  }

  Future<void> _handlePlacementFeedback(PlacementResult result) async {
    if (result.wasBombBlast) {
      _burstCells = result.clearedCells;
      _burstSeq++;
      unawaited(_sound.playBomb());
      unawaited(_haptics.bomb());
      _showPopup('+${result.pointsEarned} BOMB BLAST!', highlight: true);
    } else if (result.linesCleared > 0) {
      _burstCells = result.clearedCells;
      _burstSeq++;

      if (result.comboMultiplier >= 2) {
        unawaited(_sound.playCombo(result.comboMultiplier));
        unawaited(_haptics.combo());
        _showPopup(
          '+${result.pointsEarned} COMBO x${result.comboMultiplier}!',
          highlight: true,
        );
      } else {
        unawaited(_sound.playClearOne());
        unawaited(_haptics.clearOne());
        _showPopup('+${result.pointsEarned}');
      }

      if (result.bombSpawned) {
        // Brief second notification so player notices the Bomb Tile dropped in.
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          _showPopup('BOMB TILE DROPPED!', highlight: true);
          notifyListeners();
        });
      }
    } else {
      unawaited(_sound.playPlace());
      unawaited(_haptics.place());
    }

    if (result.becameGameOver) {
      await _onGameOverReached();
    }
  }

  Future<void> _onGameOverReached() async {
    _gamesFinishedCount = await _storage.incrementGamesFinishedCount();
    unawaited(_sound.playGameOver());
    _scheduleGameOverSafetyDelay();
  }

  /// Enforces a 1-second pause on Game Over so players never mis-tap an ad.
  void _scheduleGameOverSafetyDelay() {
    _gameOverDelayTimer?.cancel();
    _gameOverButtonsReady = false;
    _gameOverDelayTimer = Timer(const Duration(seconds: 1), () {
      _gameOverButtonsReady = true;
      notifyListeners();
    });
  }

  void _showPopup(String text, {bool highlight = false}) {
    _popupTimer?.cancel();
    _floatingPopup = FloatingPopup(
      id: ++_popupSeq,
      text: text,
      isHighlight: highlight,
    );
    _popupTimer = Timer(const Duration(milliseconds: 1150), () {
      _floatingPopup = null;
      notifyListeners();
    });
  }

  Future<void> _persistState() async {
    await _storage.saveBestScore(_engine.bestScore);
    await _storage.saveGame(_engine.toJson());
  }

  @override
  void dispose() {
    _popupTimer?.cancel();
    _gameOverDelayTimer?.cancel();
    super.dispose();
  }
}
