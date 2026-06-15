import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_config.dart';

/// Persistent application settings with multi-server support.
class SettingsProvider extends ChangeNotifier {
  static const _serversKey = 'servers';
  static const _activeServerKey = 'active_server_id';

  List<ServerConfig> _servers = [];
  String? _activeServerId;
  bool _autoPlayTts = false;

  List<ServerConfig> get servers => List.unmodifiable(_servers);
  ServerConfig? get activeServer {
    if (_activeServerId == null && _servers.isEmpty) return null;
    return _servers.firstWhere(
      (s) => s.id == _activeServerId,
      orElse: () => _servers.first,
    );
  }

  bool get autoPlayTts => _autoPlayTts;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Load servers
    final serversJson = prefs.getString(_serversKey);
    if (serversJson != null) {
      try {
        final list = jsonDecode(serversJson) as List;
        _servers = list.map((j) => ServerConfig.fromJson(j)).toList();
      } catch (_) {
        _servers = [];
      }
    }

    // Add default if empty
    if (_servers.isEmpty) {
      _servers = [ServerConfig.defaultServer()];
      await _saveServers();
    }

    // Load active server
    _activeServerId = prefs.getString(_activeServerKey);
    if (_activeServerId == null ||
        !_servers.any((s) => s.id == _activeServerId)) {
      _activeServerId = _servers.first.id;
    }

    _autoPlayTts = prefs.getBool('auto_play_tts') ?? false;
    notifyListeners();
  }

  Future<void> _saveServers() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_servers.map((s) => s.toJson()).toList());
    await prefs.setString(_serversKey, json);
  }

  /// Set the active server by ID.
  Future<void> setActiveServer(String serverId) async {
    if (!_servers.any((s) => s.id == serverId)) return;
    _activeServerId = serverId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeServerKey, serverId);
    notifyListeners();
  }

  /// Add a new server.
  Future<void> addServer(ServerConfig server) async {
    _servers.add(server);
    await _saveServers();
    // Auto-select if it's the first one
    if (_servers.length == 1) {
      await setActiveServer(server.id);
    }
    notifyListeners();
  }

  /// Update an existing server.
  Future<void> updateServer(String serverId, ServerConfig updated) async {
    final index = _servers.indexWhere((s) => s.id == serverId);
    if (index == -1) return;
    _servers[index] = updated;
    await _saveServers();
    notifyListeners();
  }

  /// Delete a server. Cannot delete the last one.
  Future<void> deleteServer(String serverId) async {
    if (_servers.length <= 1) return; // Keep at least one
    _servers.removeWhere((s) => s.id == serverId);
    await _saveServers();

    // Switch to first if active was deleted
    if (_activeServerId == serverId) {
      await setActiveServer(_servers.first.id);
    }
    notifyListeners();
  }

  /// Toggle auto-play TTS.
  Future<void> setAutoPlayTts(bool value) async {
    _autoPlayTts = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_play_tts', value);
    notifyListeners();
  }
}
