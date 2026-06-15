import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlController;
  late TextEditingController _keyController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _urlController = TextEditingController(text: settings.baseUrl);
    _keyController = TextEditingController(text: settings.apiKey);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'API Server URL',
              hintText: 'http://localhost:8642',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => settings.setBaseUrl(value),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keyController,
            decoration: const InputDecoration(
              labelText: 'API Key (optional)',
              hintText: 'Leave empty if no auth',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            onChanged: (value) => settings.setApiKey(value),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Auto-play TTS'),
            subtitle: const Text('Automatically read responses aloud'),
            value: settings.autoPlayTts,
            onChanged: (value) => settings.setAutoPlayTts(value),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const ListTile(
            title: Text('About'),
            subtitle: Text('Hermes Mobile v0.1.0'),
          ),
        ],
      ),
    );
  }
}
