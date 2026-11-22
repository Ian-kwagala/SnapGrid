import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snapgrid/logic/grid_engine.dart';
import 'package:snapgrid/main.dart';
import 'package:snapgrid/models/block_shapes.dart';
import 'package:snapgrid/services/ad_service.dart';
import 'package:snapgrid/services/haptic_service.dart';
import 'package:snapgrid/services/sound_service.dart';
import 'package:snapgrid/services/storage_service.dart';
import 'package:snapgrid/view_models/game_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GameViewModel> createInitializedViewModel({
    GridEngine? engine,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final StorageService storage = StorageService();
    final SoundService sound = SoundService(allowPlatformAudio: false);
    final HapticService haptics = HapticService(enabled: false);
    final AdService ads = AdService(enableMobileAds: false);

    final GameViewModel vm = GameViewModel(
      engine: engine ?? GridEngine(random: Random(1)),
      storage: storage,
      sound: sound,
      haptics: haptics,
      ads: ads,
    );
    await vm.init();
    addTearDown(vm.dispose);
    return vm;
  }

  testWidgets('renders SnapGrid board, score bar, tray, and Hold slot',
      (WidgetTester tester) async {
    final GameViewModel vm = await createInitializedViewModel();

    await tester.pumpWidget(SnapGridApp(viewModel: vm));
    await tester.pumpAndSettle();

    expect(find.text('0'), findsWidgets);
    expect(find.text('HOLD'), findsOneWidget);
    expect(find.text('+SLOT'), findsOneWidget);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
  });

  testWidgets('pause overlay opens and toggles sound setting',
      (WidgetTester tester) async {
    final GameViewModel vm = await createInitializedViewModel();

    await tester.pumpWidget(SnapGridApp(viewModel: vm));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.text('RESUME'), findsOneWidget);

    expect(vm.soundEnabled, isTrue);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(vm.soundEnabled, isFalse);

    await tester.tap(find.text('RESUME'));
    await tester.pumpAndSettle();
    expect(find.text('PAUSED'), findsNothing);
  });

  testWidgets('Game Over overlay enables Revive after 1-second safety delay',
      (WidgetTester tester) async {
    final GridEngine engine = GridEngine(random: Random(10));
    final fullBoard = List.generate(
      8,
      (_) => List<BlockColor?>.filled(8, BlockColor.coral),
    );
    engine.loadStateForTesting(
      board: fullBoard,
      trayPieces: [
        BlockPiece(
          instanceId: 'p0',
          shape: BlockShapeCatalog.findById('square_2x2')!,
          color: BlockColor.sky,
        ),
        null,
        null,
      ],
      holdSlots: [
        BlockPiece(
          instanceId: 'h0',
          shape: BlockShapeCatalog.findById('square_3x3')!,
          color: BlockColor.mint,
        ),
        null,
      ],
      score: 420,
    );

    final GameViewModel vm = await createInitializedViewModel(engine: engine);

    await tester.pumpWidget(SnapGridApp(viewModel: vm));
    await tester.pump();

    expect(find.text('NO MORE MOVES'), findsOneWidget);
    expect(find.text('Watch Ad to Revive & Clear 3x3'), findsOneWidget);
    expect(vm.gameOverButtonsReady, isFalse);

    // Wait past the 1-second Game Over safety delay
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(vm.gameOverButtonsReady, isTrue);

    await tester.tap(find.text('Watch Ad to Revive & Clear 3x3'));
    await tester.pumpAndSettle();
    expect(find.text('REVIVED! 3x3 CLEARED'), findsOneWidget);

    // Let the floating popup timer finish cleanly
    await tester.pump(const Duration(milliseconds: 1200));
    expect(vm.isGameOver, isFalse);
    expect(find.text('NO MORE MOVES'), findsNothing);
  });
}
