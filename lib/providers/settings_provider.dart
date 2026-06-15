import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Persistent application settings.
class SettingsProvider extends ChangeNotifier {
  String _baseUrl = AppConfig.defaultBaseUrl;
  String _apiKey = AppConfig.defaultApiKey;
  String _model = AppConfig.defaultModel;
  bool _autoPlayTts = false;

  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;
  String get model => _model;
  bool get autoPlayTts => _autoPlayTts;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('base_url') ?? AppConfig.defaultBaseUrl;
    _apiKey = prefs.getString('api_key') ?? AppConfig.defaultApiKey;
    _model = prefs.getString('model') ?? AppConfig.defaultModel;
    _autoPlayTts = prefs.getBool('auto_play_tts') ?? false;
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('base_url', url);
    notifyListeners();
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', key);
    notifyListeners();
  }

  Future<void> setAutoPlayTts(bool value) async {
    _autoPlayTts = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_play_tts', value);
    notifyListeners();
  }
}
