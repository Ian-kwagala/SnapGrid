import 'dart:math';
import '../models/block_shapes.dart';

/// Preview data returned while dragging a piece over the 8x8 grid.
class PlacementPreview {
  const PlacementPreview({
    required this.isValid,
    required this.affectedCells,
    required this.clearingRows,
    required this.clearingCols,
  });

  static const PlacementPreview invalid = PlacementPreview(
    isValid: false,
    affectedCells: [],
    clearingRows: [],
    clearingCols: [],
  );

  final bool isValid;
  final List<CellCoord> affectedCells;
  final List<int> clearingRows;
  final List<int> clearingCols;

  bool get hasLineClear => clearingRows.isNotEmpty || clearingCols.isNotEmpty;
}

/// Outcome details produced after placing a piece or blasting a Bomb Tile.
class PlacementResult {
  const PlacementResult({
    required this.success,
    this.pointsEarned = 0,
    this.linesCleared = 0,
    this.comboMultiplier = 1,
    this.wasBombBlast = false,
    this.bombSpawned = false,
    this.clearedCells = const [],
    this.becameGameOver = false,
  });

  static const PlacementResult failed = PlacementResult(success: false);

  final bool success;
  final int pointsEarned;
  final int linesCleared;
  final int comboMultiplier;
  final bool wasBombBlast;
  final bool bombSpawned;
  final List<CellCoord> clearedCells;
  final bool becameGameOver;
}

/// Pure Dart game engine managing the 8x8 SnapGrid board, scoring,
/// combos, Bomb Tiles, Hold/Swap bank slots, and offline save state.
class GridEngine {
  GridEngine({
    Random? random,
    int bestScore = 0,
  }) : _random = random ?? Random() {
    _bestScore = bestScore;
    resetGame(bestScore: bestScore);
  }

  static const int gridSize = 8;
  static const int traySize = 3;
  static const int combosPerBomb = 10;

  final Random _random;
  int _nextPieceSeq = 0;

  late List<List<BlockColor?>> _board;
  late List<BlockPiece?> _trayPieces;
  late List<BlockPiece?> _holdSlots;

  int _score = 0;
  int _bestScore = 0;
  int _comboStreak = 0;
  int _comboBombProgress = 0;
  int _pendingBombs = 0;
  bool _hasSecondHoldSlot = false;
  bool _hasUsedRevive = false;
  bool _isGameOver = false;

  // Read-only snapshots for ViewModels and tests.
  List<List<BlockColor?>> get board =>
      List<List<BlockColor?>>.unmodifiable(_board.map(List<BlockColor?>.unmodifiable));
  List<BlockPiece?> get trayPieces => List<BlockPiece?>.unmodifiable(_trayPieces);
  List<BlockPiece?> get holdSlots => List<BlockPiece?>.unmodifiable(_holdSlots);

  int get score => _score;
  int get bestScore => _bestScore;
  int get comboStreak => _comboStreak;
  int get comboBombProgress => _comboBombProgress;
  bool get hasSecondHoldSlot => _hasSecondHoldSlot;
  bool get hasUsedRevive => _hasUsedRevive;
  bool get isGameOver => _isGameOver;

  /// Starts a fresh round while preserving [bestScore] if provided.
  void resetGame({int? bestScore}) {
    if (bestScore != null && bestScore > _bestScore) {
      _bestScore = bestScore;
    }
    _board = List.generate(
      gridSize,
      (_) => List<BlockColor?>.filled(gridSize, null),
    );
    _trayPieces = List<BlockPiece?>.filled(traySize, null);
    _holdSlots = List<BlockPiece?>.filled(2, null);
    _score = 0;
    _comboStreak = 0;
    _comboBombProgress = 0;
    _pendingBombs = 0;
    _hasSecondHoldSlot = false;
    _hasUsedRevive = false;
    _isGameOver = false;
    _refillTrayIfEmpty();
    _recomputeGameOver();
  }

  /// Syncs a higher saved best score (for example, loaded from disk).
  void updateBestScore(int value) {
    if (value > _bestScore) {
      _bestScore = value;
    }
  }

  /// Unlocks the temporary 2nd Hold/Swap bank slot for the current round.
  void unlockSecondHoldSlot() {
    _hasSecondHoldSlot = true;
    _recomputeGameOver();
  }

  /// Checks whether [shape] can be placed with its top-left at ([anchorRow], [anchorCol]).
  bool canPlaceShape(BlockShape shape, int anchorRow, int anchorCol) {
    if (shape.isBomb) {
      return _inBounds(anchorRow, anchorCol);
    }
    for (final CellCoord cell in shape.cells) {
      final int r = anchorRow + cell.row;
      final int c = anchorCol + cell.col;
      if (!_inBounds(r, c) || _board[r][c] != null) {
        return false;
      }
    }
    return true;
  }

  /// Computes a non-mutating preview of placement and any rows/columns that would clear.
  PlacementPreview previewPlacement(
    BlockShape shape,
    int anchorRow,
    int anchorCol,
  ) {
    if (!canPlaceShape(shape, anchorRow, anchorCol)) {
      return PlacementPreview.invalid;
    }

    if (shape.isBomb) {
      return PlacementPreview(
        isValid: true,
        affectedCells: _blastRadiusCells(anchorRow, anchorCol),
        clearingRows: const [],
        clearingCols: const [],
      );
    }

    final Set<CellCoord> placedSet = {
      for (final cell in shape.cells)
        CellCoord(anchorRow + cell.row, anchorCol + cell.col),
    };

    // Check which rows and columns would become 100% full after this drop.
    final List<int> clearingRows = [];
    for (int r = 0; r < gridSize; r++) {
      bool full = true;
      for (int c = 0; c < gridSize; c++) {
        if (_board[r][c] == null && !placedSet.contains(CellCoord(r, c))) {
          full = false;
          break;
        }
      }
      if (full) clearingRows.add(r);
    }

    final List<int> clearingCols = [];
    for (int c = 0; c < gridSize; c++) {
      bool full = true;
      for (int r = 0; r < gridSize; r++) {
        if (_board[r][c] == null && !placedSet.contains(CellCoord(r, c))) {
          full = false;
          break;
        }
      }
      if (full) clearingCols.add(c);
    }

    return PlacementPreview(
      isValid: true,
      affectedCells: placedSet.toList(growable: false),
      clearingRows: clearingRows,
      clearingCols: clearingCols,
    );
  }

  /// Places a piece from the 3-piece tray at ([anchorRow], [anchorCol]).
  PlacementResult placeTrayPiece(int trayIndex, int anchorRow, int anchorCol) {
    if (_isGameOver || trayIndex < 0 || trayIndex >= traySize) {
      return PlacementResult.failed;
    }
    final BlockPiece? piece = _trayPieces[trayIndex];
    if (piece == null) return PlacementResult.failed;

    return _placePiece(
      piece: piece,
      anchorRow: anchorRow,
      anchorCol: anchorCol,
      consumeSource: () => _trayPieces[trayIndex] = null,
    );
  }

  /// Places a piece directly from one of the Hold/Swap slots onto the board.
  PlacementResult placeHeldPiece(int holdIndex, int anchorRow, int anchorCol) {
    if (_isGameOver || !_isHoldSlotUnlocked(holdIndex)) {
      return PlacementResult.failed;
    }
    final BlockPiece? piece = _holdSlots[holdIndex];
    if (piece == null) return PlacementResult.failed;

    return _placePiece(
      piece: piece,
      anchorRow: anchorRow,
      anchorCol: anchorCol,
      consumeSource: () => _holdSlots[holdIndex] = null,
    );
  }

  /// Moves a tray piece into [holdIndex], or swaps it with the piece already held there.
  bool holdOrSwapTrayPiece(int trayIndex, {int holdIndex = 0}) {
    if (_isGameOver ||
        trayIndex < 0 ||
        trayIndex >= traySize ||
        !_isHoldSlotUnlocked(holdIndex)) {
      return false;
    }
    final BlockPiece? trayPiece = _trayPieces[trayIndex];
    if (trayPiece == null) return false;

    final BlockPiece? heldPiece = _holdSlots[holdIndex];
    _holdSlots[holdIndex] = trayPiece;
    _trayPieces[trayIndex] = heldPiece;

    // If parking the last tray piece left the tray empty, deal 3 fresh pieces.
    _refillTrayIfEmpty();
    _recomputeGameOver();
    return true;
  }

  /// Uses the 1-per-round Rewarded Ad revive to blast the densest 3x3 area.
  List<CellCoord> reviveWithBombClear() {
    if (!_isGameOver || _hasUsedRevive) {
      return const [];
    }

    final CellCoord target = _findBestBlastCenter();
    final List<CellCoord> blasted = _blastRadiusCells(target.row, target.col);
    for (final CellCoord cell in blasted) {
      _board[cell.row][cell.col] = null;
    }

    _hasUsedRevive = true;
    _recomputeGameOver();

    // If every remaining piece is still somehow unplaceable (e.g. a lone 5x1
    // surrounded by isolated cells), guarantee at least one small playable piece.
    if (_isGameOver) {
      for (int i = 0; i < traySize; i++) {
        if (_trayPieces[i] != null) {
          _trayPieces[i] = BlockPiece(
            instanceId: _nextId(),
            shape: BlockShapeCatalog.standardShapes.first, // dot_1x1
            color: _trayPieces[i]!.color,
          );
          break;
        }
      }
      _recomputeGameOver();
    }

    return blasted;
  }

  /// Shared placement pipeline for both tray pieces and held pieces.
  PlacementResult _placePiece({
    required BlockPiece piece,
    required int anchorRow,
    required int anchorCol,
    required void Function() consumeSource,
  }) {
    final PlacementPreview preview = previewPlacement(
      piece.shape,
      anchorRow,
      anchorCol,
    );
    if (!preview.isValid) {
      return PlacementResult.failed;
    }

    consumeSource();

    if (piece.isBomb) {
      final List<CellCoord> cleared = [];
      for (final CellCoord cell in preview.affectedCells) {
        if (_board[cell.row][cell.col] != null) {
          cleared.add(cell);
          _board[cell.row][cell.col] = null;
        }
      }
      final int earned = max(30, cleared.length * 15);
      _addScore(earned);

      _refillTrayIfEmpty();
      _recomputeGameOver();

      return PlacementResult(
        success: true,
        pointsEarned: earned,
        wasBombBlast: true,
        clearedCells: cleared,
        becameGameOver: _isGameOver,
      );
    }

    // Place normal polyomino cells onto the board.
    for (final CellCoord cell in preview.affectedCells) {
      _board[cell.row][cell.col] = piece.color;
    }

    final int placementPoints = preview.affectedCells.length * 10;
    final int linesCleared =
        preview.clearingRows.length + preview.clearingCols.length;

    // Collect and clear all full rows and columns simultaneously.
    final Set<CellCoord> clearedSet = {};
    for (final int r in preview.clearingRows) {
      for (int c = 0; c < gridSize; c++) {
        clearedSet.add(CellCoord(r, c));
      }
    }
    for (final int c in preview.clearingCols) {
      for (int r = 0; r < gridSize; r++) {
        clearedSet.add(CellCoord(r, c));
      }
    }
    for (final CellCoord cell in clearedSet) {
      _board[cell.row][cell.col] = null;
    }

    int comboMultiplier = 1;
    int lineBonus = 0;
    bool bombSpawned = false;

    if (linesCleared > 0) {
      _comboStreak += 1;
      // Combo triggers on 2+ lines at once or back-to-back clearing turns.
      comboMultiplier = max(
        1,
        _comboStreak + (linesCleared > 1 ? linesCleared - 1 : 0),
      );
      lineBonus = linesCleared * 100 * comboMultiplier;

      if (comboMultiplier >= 2) {
        _comboBombProgress += 1;
        if (_comboBombProgress >= combosPerBomb) {
          _comboBombProgress -= combosPerBomb;
          _pendingBombs += 1;
        }
      }
    } else {
      _comboStreak = 0;
    }

    final int totalPoints = placementPoints + lineBonus;
    _addScore(totalPoints);

    _refillTrayIfEmpty();
    if (_pendingBombs > 0) {
      bombSpawned = _deliverPendingBombToTray();
    }
    _recomputeGameOver();

    return PlacementResult(
      success: true,
      pointsEarned: totalPoints,
      linesCleared: linesCleared,
      comboMultiplier: comboMultiplier,
      bombSpawned: bombSpawned,
      clearedCells: clearedSet.toList(growable: false),
      becameGameOver: _isGameOver,
    );
  }

  /// Converts the first available non-bomb tray piece into a glowing Bomb Tile.
  bool _deliverPendingBombToTray() {
    if (_pendingBombs <= 0) return false;
    for (int i = 0; i < traySize; i++) {
      final BlockPiece? current = _trayPieces[i];
      if (current != null && !current.isBomb) {
        _trayPieces[i] = BlockPiece(
          instanceId: _nextId(),
          shape: BlockShapeCatalog.bombTile,
          color: BlockColor.amber,
        );
        _pendingBombs -= 1;
        return true;
      }
    }
    return false;
  }

  void _refillTrayIfEmpty() {
    final bool hasAnyPiece = _trayPieces.any((p) => p != null);
    if (hasAnyPiece) return;

    for (int i = 0; i < traySize; i++) {
      if (_pendingBombs > 0) {
        _trayPieces[i] = BlockPiece(
          instanceId: _nextId(),
          shape: BlockShapeCatalog.bombTile,
          color: BlockColor.amber,
        );
        _pendingBombs -= 1;
      } else {
        _trayPieces[i] = _generateRandomPiece();
      }
    }
  }

  BlockPiece _generateRandomPiece() {
    final List<BlockShape> shapes = BlockShapeCatalog.standardShapes;
    int totalWeight = 0;
    for (final shape in shapes) {
      totalWeight += shape.weight;
    }

    int roll = _random.nextInt(totalWeight);
    BlockShape chosen = shapes.first;
    for (final shape in shapes) {
      roll -= shape.weight;
      if (roll < 0) {
        chosen = shape;
        break;
      }
    }

    final BlockColor color =
        BlockColor.values[_random.nextInt(BlockColor.values.length)];
    return BlockPiece(
      instanceId: _nextId(),
      shape: chosen,
      color: color,
    );
  }

  void _recomputeGameOver() {
    // 1. Check if any piece in the tray can fit somewhere on the board.
    for (final BlockPiece? piece in _trayPieces) {
      if (piece != null && _canFitAnywhere(piece.shape)) {
        _isGameOver = false;
        return;
      }
    }

    // 2. Check if any held piece can fit somewhere on the board.
    for (int i = 0; i < _holdSlots.length; i++) {
      if (!_isHoldSlotUnlocked(i)) continue;
      final BlockPiece? held = _holdSlots[i];
      if (held != null && _canFitAnywhere(held.shape)) {
        _isGameOver = false;
        return;
      }
    }

    // 3. If an unlocked Hold Slot is empty and there is a tray piece, the player
    //    can still park a piece to uncover or deal new pieces.
    final bool hasTrayPiece = _trayPieces.any((p) => p != null);
    final bool hasEmptyUnlockedHold = [0, 1].any(
      (i) => _isHoldSlotUnlocked(i) && _holdSlots[i] == null,
    );
    if (hasTrayPiece && hasEmptyUnlockedHold) {
      _isGameOver = false;
      return;
    }

    _isGameOver = true;
  }

  bool _canFitAnywhere(BlockShape shape) {
    if (shape.isBomb) return true;
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (canPlaceShape(shape, r, c)) {
          return true;
        }
      }
    }
    return false;
  }

  CellCoord _findBestBlastCenter() {
    CellCoord best = const CellCoord(3, 3);
    int bestCount = -1;

    for (int r = 1; r <= gridSize - 2; r++) {
      for (int c = 1; c <= gridSize - 2; c++) {
        int filled = 0;
        for (final CellCoord cell in _blastRadiusCells(r, c)) {
          if (_board[cell.row][cell.col] != null) {
            filled++;
          }
        }
        if (filled > bestCount) {
          bestCount = filled;
          best = CellCoord(r, c);
        }
      }
    }
    return best;
  }

  List<CellCoord> _blastRadiusCells(int centerRow, int centerCol) {
    final List<CellCoord> cells = [];
    for (int r = max(0, centerRow - 1); r <= min(gridSize - 1, centerRow + 1); r++) {
      for (int c = max(0, centerCol - 1); c <= min(gridSize - 1, centerCol + 1); c++) {
        cells.add(CellCoord(r, c));
      }
    }
    return cells;
  }

  bool _isHoldSlotUnlocked(int holdIndex) {
    if (holdIndex == 0) return true;
    if (holdIndex == 1) return _hasSecondHoldSlot;
    return false;
  }

  bool _inBounds(int row, int col) {
    return row >= 0 && row < gridSize && col >= 0 && col < gridSize;
  }

  void _addScore(int points) {
    _score += points;
    if (_score > _bestScore) {
      _bestScore = _score;
    }
  }

  String _nextId() => 'piece_${_nextPieceSeq++}';

  // ---------- TEST / SERIALIZATION HELPERS ----------

  /// Replaces board contents directly (used by serialization and unit tests).
  void loadStateForTesting({
    required List<List<BlockColor?>> board,
    required List<BlockPiece?> trayPieces,
    List<BlockPiece?>? holdSlots,
    int score = 0,
    int comboStreak = 0,
    int comboBombProgress = 0,
    bool hasSecondHoldSlot = false,
    bool hasUsedRevive = false,
  }) {
    _board = board.map((r) => List<BlockColor?>.from(r)).toList();
    _trayPieces = List<BlockPiece?>.from(trayPieces);
    _holdSlots = holdSlots != null
        ? List<BlockPiece?>.from(holdSlots)
        : [null, null];
    _score = score;
    if (_score > _bestScore) _bestScore = _score;
    _comboStreak = comboStreak;
    _comboBombProgress = comboBombProgress;
    _hasSecondHoldSlot = hasSecondHoldSlot;
    _hasUsedRevive = hasUsedRevive;
    _recomputeGameOver();
  }

  /// Serializes the active game so players can close and resume seamlessly offline.
  Map<String, dynamic> toJson() {
    return {
      'board': _board
          .map((row) => row.map((cell) => cell?.name).toList())
          .toList(),
      'trayPieces': _trayPieces.map((p) => p?.toJson()).toList(),
      'holdSlots': _holdSlots.map((p) => p?.toJson()).toList(),
      'score': _score,
      'bestScore': _bestScore,
      'comboStreak': _comboStreak,
      'comboBombProgress': _comboBombProgress,
      'pendingBombs': _pendingBombs,
      'hasSecondHoldSlot': _hasSecondHoldSlot,
      'hasUsedRevive': _hasUsedRevive,
      'isGameOver': _isGameOver,
    };
  }

  /// Restores saved game state; returns false if the payload is invalid.
  bool restoreFromJson(Map<String, dynamic> json) {
    try {
      final List<dynamic> rawBoard = json['board'] as List<dynamic>;
      if (rawBoard.length != gridSize) return false;

      final List<List<BlockColor?>> parsedBoard = [];
      for (final dynamic rawRow in rawBoard) {
        final List<dynamic> rowList = rawRow as List<dynamic>;
        if (rowList.length != gridSize) return false;
        parsedBoard.add(
          rowList
              .map((cell) => cell == null ? null : BlockColor.fromName(cell as String))
              .toList(),
        );
      }

      final List<dynamic> rawTray = json['trayPieces'] as List<dynamic>;
      final List<dynamic> rawHold = json['holdSlots'] as List<dynamic>;
      if (rawTray.length != traySize || rawHold.length != 2) return false;

      _board = parsedBoard;
      _trayPieces = rawTray
          .map((item) => BlockPiece.fromJson(item as Map<String, dynamic>?))
          .toList();
      _holdSlots = rawHold
          .map((item) => BlockPiece.fromJson(item as Map<String, dynamic>?))
          .toList();
      _score = (json['score'] as int?) ?? 0;
      _bestScore = max(_bestScore, (json['bestScore'] as int?) ?? 0);
      _comboStreak = (json['comboStreak'] as int?) ?? 0;
      _comboBombProgress = (json['comboBombProgress'] as int?) ?? 0;
      _pendingBombs = (json['pendingBombs'] as int?) ?? 0;
      _hasSecondHoldSlot = (json['hasSecondHoldSlot'] as bool?) ?? false;
      _hasUsedRevive = (json['hasUsedRevive'] as bool?) ?? false;
      _recomputeGameOver();
      return true;
    } catch (_) {
      return false;
    }
  }
}
