import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'logic/grid_engine.dart';
import 'screens/game_screen.dart';
import 'services/ad_service.dart';
import 'services/haptic_service.dart';
import 'services/sound_service.dart';
import 'services/storage_service.dart';
import 'theme/snapgrid_theme.dart';
import 'view_models/game_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock portrait mode for consistent 8x8 board and tray proportions on phones.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: SnapGridColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final AdService adService = AdService();
  // Request UMP consent and initialize AdMob in the background so startup is instant.
  unawaited(adService.initialize());

  runApp(SnapGridApp(adService: adService));
}

/// Root widget for SnapGrid: Block Puzzle.
class SnapGridApp extends StatefulWidget {
  const SnapGridApp({
    super.key,
    this.viewModel,
    this.adService,
  });

  final GameViewModel? viewModel;
  final AdService? adService;

  @override
  State<SnapGridApp> createState() => _SnapGridAppState();
}

class _SnapGridAppState extends State<SnapGridApp> {
  late final bool _ownsViewModel = widget.viewModel == null;
  late final SoundService _soundService;
  late final AdService _adService;
  late final GameViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    if (widget.viewModel != null) {
      _viewModel = widget.viewModel!;
    } else {
      _soundService = SoundService();
      _adService = widget.adService ?? AdService();
      _viewModel = GameViewModel(
        engine: GridEngine(),
        storage: StorageService(),
        sound: _soundService,
        haptics: HapticService(),
        ads: _adService,
      );
      unawaited(_viewModel.init());
    }
  }

  @override
  void dispose() {
    if (_ownsViewModel) {
      _viewModel.dispose();
      _soundService.dispose();
      if (widget.adService == null) {
        _adService.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapGrid: Block Puzzle',
      debugShowCheckedModeBanner: false,
      theme: buildSnapGridTheme(),
      home: GameScreen(viewModel: _viewModel),
    );
  }
}
