import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/server_config.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../services/relay_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Servers')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showServerDialog(context),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: [
          // Relay discovery
          const _RelaySection(),

          const Divider(),

          // Server list
          ...settings.servers.map((server) {
            final isActive = server.id == settings.activeServer?.id;
            return _ServerTile(
              server: server,
              isActive: isActive,
              onTap: () => settings.setActiveServer(server.id),
              onEdit: () => _showServerDialog(context, existing: server),
              onDelete: settings.servers.length > 1
                  ? () => _confirmDelete(context, settings, server)
                  : null,
            );
          }),

          const Divider(),

          // Preferences
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: settings.darkMode,
            onChanged: (v) => settings.setDarkMode(v),
          ),
          SwitchListTile(
            title: const Text('Auto-play TTS'),
            subtitle: const Text('Read responses aloud automatically'),
            value: settings.autoPlayTts,
            onChanged: (v) => settings.setAutoPlayTts(v),
          ),
          const ListTile(
            title: Text('About'),
            subtitle: Text('Hermes Mobile v0.1.0'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, SettingsProvider settings, ServerConfig server) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Server'),
        content: Text('Remove "${server.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              settings.deleteServer(server.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showServerDialog(BuildContext context, {ServerConfig? existing}) {
    showDialog(
      context: context,
      builder: (ctx) => _ServerDialog(existing: existing),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Relay discovery section
// ──────────────────────────────────────────────────────────────────────

class _RelaySection extends StatefulWidget {
  const _RelaySection();

  @override
  State<_RelaySection> createState() => _RelaySectionState();
}

class _RelaySectionState extends State<_RelaySection> {
  final RelayService _relay = RelayService();
  final _urlController = TextEditingController(text: 'ws://');
  final _authController = TextEditingController();
  bool _connecting = false;
  bool _connected = false;
  List<RelayInstance> _instances = [];
  StreamSubscription? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    _relay.dispose();
    _urlController.dispose();
    _authController.dispose();
    super.dispose();
  }

  Future<void> _toggleConnection() async {
    if (_connected) {
      _relay.disconnect();
      setState(() {
        _connected = false;
        _instances = [];
      });
      return;
    }

    setState(() => _connecting = true);
    final ok = await _relay.connect(_urlController.text,
        auth: _authController.text.isNotEmpty ? _authController.text : null);
    if (ok) {
      _sub = _relay.instances.listen((list) {
        setState(() => _instances = list);
      });
    }
    setState(() {
      _connecting = false;
      _connected = ok;
    });
  }

  void _addInstance(RelayInstance instance) {
    final settings = context.read<SettingsProvider>();
    final config = ServerConfig(
      id: 'relay-${instance.id}',
      name: instance.name,
      baseUrl: _urlController.text,
      apiKey: _authController.text,
    );
    settings.addServer(config);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${instance.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud, size: 20),
              const SizedBox(width: 8),
              Text('Relay Discovery',
                  style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Relay URL',
                    hintText: 'ws://vps:9920',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _connecting ? null : _toggleConnection,
                child: _connecting
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_connected ? 'Disconnect' : 'Connect'),
              ),
            ],
          ),
          if (_connected) ...[
            const SizedBox(height: 4),
            TextField(
              controller: _authController,
              decoration: const InputDecoration(
                labelText: 'Auth Key (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
          if (_connected && _instances.isEmpty) ...[
            const SizedBox(height: 8),
            const Text('No Hermes instances found. Start the Bridge on your Hermes machine.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
          if (_instances.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Discovered (${_instances.length}):',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            ..._instances.map((inst) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.computer, size: 20),
                  title: Text(inst.name),
                  trailing: TextButton(
                    onPressed: () => _addInstance(inst),
                    child: const Text('Add'),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

// ... (existing _ServerTile and _ServerDialog classes unchanged)

class _ServerTile extends StatelessWidget {
  final ServerConfig server;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ServerTile({
    required this.server,
    required this.isActive,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        isActive ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isActive ? theme.colorScheme.primary : null,
      ),
      title: Text(server.name),
      subtitle: Text(server.baseUrl, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null)
            IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: onEdit),
          if (onDelete != null)
            IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: onDelete),
        ],
      ),
    );
  }
}

class _ServerDialog extends StatefulWidget {
  final ServerConfig? existing;
  const _ServerDialog({this.existing});

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _keyCtrl;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _urlCtrl = TextEditingController(text: widget.existing?.baseUrl ?? 'http://localhost:8642');
    _keyCtrl = TextEditingController(text: widget.existing?.apiKey ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() { _testing = true; _testResult = null; });
    final api = ApiService(baseUrl: _urlCtrl.text, apiKey: _keyCtrl.text);
    final ok = await api.healthCheck();
    setState(() {
      _testing = false;
      _testResult = ok ? '✓ Connected' : '✗ Connection failed';
    });
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    if (name.isEmpty || url.isEmpty) return;
    final settings = context.read<SettingsProvider>();
    final config = ServerConfig(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: name,
      baseUrl: url,
      apiKey: _keyCtrl.text.trim(),
    );
    if (widget.existing != null) {
      settings.updateServer(widget.existing!.id, config);
    } else {
      settings.addServer(config);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing != null ? 'Edit Server' : 'Add Server'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name', hintText: 'Home Mac')),
          const SizedBox(height: 12),
          TextField(controller: _urlCtrl, decoration: const InputDecoration(labelText: 'URL', hintText: 'http://192.168.1.100:8642')),
          const SizedBox(height: 12),
          TextField(controller: _keyCtrl, decoration: const InputDecoration(labelText: 'API Key (optional)'), obscureText: true),
          if (_testResult != null) ...[
            const SizedBox(height: 8),
            Text(_testResult!, style: TextStyle(color: _testResult!.startsWith('✓') ? Colors.green : Colors.red)),
          ],
        ]),
      ),
      actions: [
        TextButton(
          onPressed: _testing ? null : _testConnection,
          child: _testing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Test'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
