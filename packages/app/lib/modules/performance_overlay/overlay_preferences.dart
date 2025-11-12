/// Persistence layer for performance overlay state.
///
/// This module provides loading and saving of overlay state to persistent
/// storage (SharedPreferences) with reset-to-defaults functionality.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'overlay_state.dart';

/// Preferences key for overlay state.
const String _overlayStateKey = 'performance_overlay_state';

/// Preferences manager for performance overlay state.
///
/// Handles loading/saving overlay position, visibility, and docking
/// preferences to persistent storage.
class OverlayPreferences {
  /// Creates an overlay preferences manager.
  const OverlayPreferences(this._prefs);

  final SharedPreferences _prefs;

  /// Loads overlay state from preferences.
  ///
  /// Returns default state if no saved state exists or if loading fails.
  PerformanceOverlayState loadState() {
    try {
      final json = _prefs.getString(_overlayStateKey);
      if (json == null) {
        return PerformanceOverlayState.defaultState();
      }

      final Map<String, dynamic> data =
          jsonDecode(json) as Map<String, dynamic>;
      return PerformanceOverlayState.fromJson(data);
    } catch (e) {
      // Return default state on error
      return PerformanceOverlayState.defaultState();
    }
  }

  /// Saves overlay state to preferences.
  ///
  /// Returns true if save succeeded, false otherwise.
  Future<bool> saveState(PerformanceOverlayState state) async {
    try {
      final json = jsonEncode(state.toJson());
      return await _prefs.setString(_overlayStateKey, json);
    } catch (e) {
      return false;
    }
  }

  /// Resets overlay state to defaults.
  ///
  /// Removes saved preferences and returns default state.
  Future<PerformanceOverlayState> resetToDefaults() async {
    await _prefs.remove(_overlayStateKey);
    return PerformanceOverlayState.defaultState();
  }

  /// Checks if saved state exists.
  bool hasSavedState() {
    return _prefs.containsKey(_overlayStateKey);
  }
}

/// Preferences key for telemetry config.
const String _telemetryConfigKey = 'telemetry_config';

/// Preferences manager for telemetry configuration.
///
/// Handles loading/saving telemetry opt-in/opt-out state and other
/// configuration to persistent storage.
class TelemetryPreferences {
  /// Creates a telemetry preferences manager.
  const TelemetryPreferences(this._prefs);

  final SharedPreferences _prefs;

  /// Loads telemetry configuration from preferences.
  ///
  /// Returns null if no saved config exists.
  Map<String, dynamic>? loadConfig() {
    try {
      final json = _prefs.getString(_telemetryConfigKey);
      if (json == null) return null;

      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Saves telemetry configuration to preferences.
  ///
  /// Returns true if save succeeded, false otherwise.
  Future<bool> saveConfig(Map<String, dynamic> config) async {
    try {
      final json = jsonEncode(config);
      return await _prefs.setString(_telemetryConfigKey, json);
    } catch (e) {
      return false;
    }
  }

  /// Clears telemetry configuration.
  Future<void> clearConfig() async {
    await _prefs.remove(_telemetryConfigKey);
  }

  /// Checks if saved config exists.
  bool hasSavedConfig() {
    return _prefs.containsKey(_telemetryConfigKey);
  }
}
