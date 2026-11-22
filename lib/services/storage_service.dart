import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists SnapGrid scores, preferences, and active board state locally.
///
/// Everything stays on the user's device via [SharedPreferences] so gameplay
/// works 100% offline with zero server dependencies.
class StorageService {
  StorageService({this._prefs});

  static const String _keyBestScore = 'snapgrid_best_score';
  static const String _keySoundEnabled = 'snapgrid_sound_enabled';
  static const String _keyHapticsEnabled = 'snapgrid_haptics_enabled';
  static const String _keyGamesFinished = 'snapgrid_games_finished';
  static const String _keySavedGame = 'snapgrid_saved_game';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> init() async {
    await _getPrefs();
  }

  Future<int> getBestScore() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_keyBestScore) ?? 0;
  }

  Future<void> saveBestScore(int score) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_keyBestScore, score);
  }

  Future<bool> isSoundEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keySoundEnabled) ?? true;
  }

  Future<void> setSoundEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keySoundEnabled, enabled);
  }

  Future<bool> isHapticsEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyHapticsEnabled) ?? true;
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyHapticsEnabled, enabled);
  }

  Future<int> getGamesFinishedCount() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_keyGamesFinished) ?? 0;
  }

  Future<int> incrementGamesFinishedCount() async {
    final prefs = await _getPrefs();
    final int next = (prefs.getInt(_keyGamesFinished) ?? 0) + 1;
    await prefs.setInt(_keyGamesFinished, next);
    return next;
  }

  Future<Map<String, dynamic>?> loadSavedGame() async {
    final prefs = await _getPrefs();
    final String? raw = prefs.getString(_keySavedGame);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveGame(Map<String, dynamic> state) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keySavedGame, jsonEncode(state));
  }

  Future<void> clearSavedGame() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keySavedGame);
  }
}
