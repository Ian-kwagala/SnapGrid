import 'package:audioplayers/audioplayers.dart';

/// Plays short offline `.wav` sound effects for SnapGrid game events.
class SoundService {
  SoundService({
    this.enabled = true,
    this._allowPlatformAudio = true,
  });

  bool enabled;
  final bool _allowPlatformAudio;

  // Lazily created so headless tests never hang on missing platform channels.
  AudioPlayer? _fxPlayer;
  AudioPlayer? _comboPlayer;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || !enabled || !_allowPlatformAudio) return;
    _initialized = true;
    try {
      _fxPlayer ??= AudioPlayer();
      _comboPlayer ??= AudioPlayer();
      await _fxPlayer!.setPlayerMode(PlayerMode.lowLatency);
      await _comboPlayer!.setPlayerMode(PlayerMode.mediaPlayer);
    } catch (_) {
      // Ignore audio plugin errors in headless or test environments.
    }
  }

  Future<void> playPickup() => _playFx('sounds/pickup.wav');

  Future<void> playPlace() => _playFx('sounds/place.wav');

  Future<void> playClearOne() => _playCombo('sounds/clear_one.wav');

  /// Plays the rising musical arpeggio with a slight pitch boost per combo.
  Future<void> playCombo(int comboMultiplier) async {
    final double rate = (1.0 + (comboMultiplier - 2).clamp(0, 6) * 0.06);
    await _playCombo('sounds/combo.wav', playbackRate: rate);
  }

  Future<void> playBomb() => _playCombo('sounds/bomb.wav');

  Future<void> playGameOver() => _playCombo('sounds/game_over.wav');

  Future<void> _playFx(String assetPath) async {
    if (!enabled || !_allowPlatformAudio) return;
    await init();
    final AudioPlayer? player = _fxPlayer;
    if (player == null) return;
    await _play(player, assetPath);
  }

  Future<void> _playCombo(String assetPath, {double playbackRate = 1.0}) async {
    if (!enabled || !_allowPlatformAudio) return;
    await init();
    final AudioPlayer? player = _comboPlayer;
    if (player == null) return;
    await _play(player, assetPath, playbackRate: playbackRate);
  }

  Future<void> _play(
    AudioPlayer player,
    String assetPath, {
    double playbackRate = 1.0,
  }) async {
    if (!enabled) return;
    try {
      await player.stop();
      await player.setPlaybackRate(playbackRate);
      await player.play(AssetSource(assetPath));
    } catch (_) {
      // Sound playback should never interrupt gameplay.
    }
  }

  void dispose() {
    _fxPlayer?.dispose();
    _comboPlayer?.dispose();
  }
}
