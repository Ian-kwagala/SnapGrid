import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapgrid/logic/grid_engine.dart';
import 'package:snapgrid/models/block_shapes.dart';

void main() {
  BlockPiece makePiece(String shapeId, {BlockColor color = BlockColor.coral}) {
    final BlockShape shape = BlockShapeCatalog.findById(shapeId)!;
    return BlockPiece(
      instanceId: 'test_$shapeId',
      shape: shape,
      color: color,
    );
  }

  List<List<BlockColor?>> emptyBoard() => List.generate(
        GridEngine.gridSize,
        (_) => List<BlockColor?>.filled(GridEngine.gridSize, null),
      );

  group('GridEngine', () {
    test('initializes an empty 8x8 board and 3 tray pieces', () {
      final GridEngine engine = GridEngine(random: Random(1));
      expect(engine.board.length, equals(8));
      expect(engine.board.every((row) => row.length == 8), isTrue);
      expect(
        engine.board.every((row) => row.every((cell) => cell == null)),
        isTrue,
      );
      expect(engine.trayPieces.whereType<BlockPiece>().length, equals(3));
      expect(engine.score, equals(0));
      expect(engine.isGameOver, isFalse);
    });

    test('rejects out-of-bounds and overlapping placements', () {
      final GridEngine engine = GridEngine(random: Random(2));
      final board = emptyBoard();
      board[0][0] = BlockColor.sky;

      engine.loadStateForTesting(
        board: board,
        trayPieces: [makePiece('square_2x2'), null, null],
      );

      // Overlaps occupied (0, 0)
      expect(engine.placeTrayPiece(0, 0, 0).success, isFalse);
      // Out of bounds at col 7 for a 2x2 piece
      expect(engine.placeTrayPiece(0, 0, 7).success, isFalse);
      // Valid placement at (0, 1)
      expect(engine.placeTrayPiece(0, 0, 1).success, isTrue);
    });

    test('clears full rows and columns simultaneously and triggers combo', () {
      final GridEngine engine = GridEngine(random: Random(3));
      final board = emptyBoard();

      // Fill row 0 except col 0, and fill col 0 except row 0
      for (int c = 1; c < 8; c++) {
        board[0][c] = BlockColor.mint;
      }
      for (int r = 1; r < 8; r++) {
        board[r][0] = BlockColor.violet;
      }

      engine.loadStateForTesting(
        board: board,
        trayPieces: [makePiece('dot_1x1'), makePiece('dot_1x1'), null],
      );

      final PlacementPreview preview =
          engine.previewPlacement(BlockShapeCatalog.findById('dot_1x1')!, 0, 0);
      expect(preview.clearingRows, equals([0]));
      expect(preview.clearingCols, equals([0]));

      final PlacementResult result = engine.placeTrayPiece(0, 0, 0);
      expect(result.success, isTrue);
      expect(result.linesCleared, equals(2));
      expect(result.comboMultiplier, equals(2));
      expect(engine.comboStreak, equals(1));
      expect(engine.comboBombProgress, equals(1));
      // All cells in row 0 and col 0 should now be empty
      for (int i = 0; i < 8; i++) {
        expect(engine.board[0][i], isNull);
        expect(engine.board[i][0], isNull);
      }
    });

    test('triggers back-to-back combo and resets on non-clearing move', () {
      final GridEngine engine = GridEngine(random: Random(4));
      final board = emptyBoard();
      for (int c = 1; c < 8; c++) {
        board[0][c] = BlockColor.coral;
        board[1][c] = BlockColor.sky;
      }

      engine.loadStateForTesting(
        board: board,
        trayPieces: [
          makePiece('dot_1x1'),
          makePiece('dot_1x1'),
          makePiece('dot_1x1'),
        ],
      );

      final r1 = engine.placeTrayPiece(0, 0, 0);
      expect(r1.linesCleared, equals(1));
      expect(r1.comboMultiplier, equals(1));

      final r2 = engine.placeTrayPiece(1, 1, 0);
      expect(r2.linesCleared, equals(1));
      expect(r2.comboMultiplier, equals(2)); // Back-to-back combo!
      expect(engine.comboBombProgress, equals(1));

      // Non-clearing placement resets combo streak
      final r3 = engine.placeTrayPiece(2, 4, 4);
      expect(r3.linesCleared, equals(0));
      expect(engine.comboStreak, equals(0));
    });

    test('drops a Bomb Tile every 10 combos and blasts a 3x3 area anywhere', () {
      final GridEngine engine = GridEngine(random: Random(5));
      final board = emptyBoard();
      for (int c = 1; c < 8; c++) {
        board[0][c] = BlockColor.amber;
        board[1][c] = BlockColor.amber;
      }

      engine.loadStateForTesting(
        board: board,
        trayPieces: [makePiece('dot_1x1'), makePiece('dot_1x1'), null],
        comboStreak: 1,
        comboBombProgress: 9,
      );

      // 10th combo should spawn a Bomb Tile into the tray
      final PlacementResult comboResult = engine.placeTrayPiece(0, 0, 0);
      expect(comboResult.comboMultiplier, greaterThanOrEqualTo(2));
      expect(comboResult.bombSpawned, isTrue);
      expect(engine.comboBombProgress, equals(0));
      expect(engine.trayPieces[1]?.isBomb, isTrue);

      // Fill a 3x3 cluster around (4, 4) and blast it with the Bomb Tile
      for (int r = 3; r <= 5; r++) {
        for (int c = 3; c <= 5; c++) {
          board[r][c] = BlockColor.violet;
        }
      }
      engine.loadStateForTesting(
        board: board,
        trayPieces: [engine.trayPieces[1], makePiece('dot_1x1'), null],
      );

      final PlacementResult blast = engine.placeTrayPiece(0, 4, 4);
      expect(blast.success, isTrue);
      expect(blast.wasBombBlast, isTrue);
      expect(blast.clearedCells.length, equals(9));
      for (int r = 3; r <= 5; r++) {
        for (int c = 3; c <= 5; c++) {
          expect(engine.board[r][c], isNull);
        }
      }
    });

    test('supports Hold/Swap bank slot and temporary 2nd Hold Slot', () {
      final GridEngine engine = GridEngine(random: Random(6));
      final p0 = makePiece('square_3x3');
      final p1 = makePiece('dot_1x1');

      engine.loadStateForTesting(
        board: emptyBoard(),
        trayPieces: [p0, p1, null],
      );

      // Slot 1 is locked initially
      expect(engine.holdOrSwapTrayPiece(0, holdIndex: 1), isFalse);

      // Park p0 in Slot 0
      expect(engine.holdOrSwapTrayPiece(0, holdIndex: 0), isTrue);
      expect(engine.holdSlots[0]?.shape.id, equals('square_3x3'));
      expect(engine.trayPieces[0], isNull);

      // Swap p1 with held p0
      expect(engine.holdOrSwapTrayPiece(1, holdIndex: 0), isTrue);
      expect(engine.holdSlots[0]?.shape.id, equals('dot_1x1'));
      expect(engine.trayPieces[1]?.shape.id, equals('square_3x3'));

      // Place held piece directly onto the board
      final placed = engine.placeHeldPiece(0, 7, 7);
      expect(placed.success, isTrue);
      expect(engine.holdSlots[0], isNull);

      // Unlock 2nd Hold Slot and verify it works
      engine.unlockSecondHoldSlot();
      expect(engine.hasSecondHoldSlot, isTrue);
      expect(engine.holdOrSwapTrayPiece(1, holdIndex: 1), isTrue);
      expect(engine.holdSlots[1]?.shape.id, equals('square_3x3'));
    });

    test('detects Game Over accurately and allows 1-per-round 3x3 Revive', () {
      final GridEngine engine = GridEngine(random: Random(7));
      final board = List.generate(
        8,
        (_) => List<BlockColor?>.filled(8, BlockColor.coral),
      );

      engine.loadStateForTesting(
        board: board,
        trayPieces: [makePiece('square_2x2'), null, null],
        holdSlots: [makePiece('square_3x3'), null],
      );

      expect(engine.isGameOver, isTrue);

      final List<CellCoord> cleared = engine.reviveWithBombClear();
      expect(cleared.length, equals(9));
      expect(engine.hasUsedRevive, isTrue);
      expect(engine.isGameOver, isFalse);

      // Cannot revive a second time in the same round
      expect(engine.reviveWithBombClear(), isEmpty);
    });

    test('serializes and restores board, tray, hold slots, and score', () {
      final GridEngine original = GridEngine(random: Random(8));
      original.placeTrayPiece(0, 0, 0);
      original.holdOrSwapTrayPiece(1, holdIndex: 0);
      original.unlockSecondHoldSlot();

      final Map<String, dynamic> json = original.toJson();
      final GridEngine restored = GridEngine(random: Random(99));
      expect(restored.restoreFromJson(json), isTrue);

      expect(restored.score, equals(original.score));
      expect(restored.hasSecondHoldSlot, isTrue);
      expect(
        restored.holdSlots[0]?.shape.id,
        equals(original.holdSlots[0]?.shape.id),
      );
      expect(restored.board, equals(original.board));
    });
  });
}
