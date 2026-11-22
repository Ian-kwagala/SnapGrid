import 'package:flutter/services.dart';

/// Maps SnapGrid gameplay events to subtle phone vibrations.
class HapticService {
  HapticService({this.enabled = true});

  bool enabled;

  Future<void> pickup() async {
    if (!enabled) return;
    await HapticFeedback.selectionClick();
  }

  Future<void> place() async {
    if (!enabled) return;
    await HapticFeedback.lightImpact();
  }

  Future<void> clearOne() async {
    if (!enabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// Double pulse vibration for 2+ line clears and combo streaks.
  Future<void> combo() async {
    if (!enabled) return;
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 70));
    if (enabled) {
      await HapticFeedback.mediumImpact();
    }
  }

  Future<void> bomb() async {
    if (!enabled) return;
    await HapticFeedback.heavyImpact();
  }
}
