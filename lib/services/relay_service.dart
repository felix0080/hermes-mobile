import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket client for Hermes Relay.
///
/// Connects to a Relay server, discovers Hermes instances,
/// and routes chat messages with streaming responses.
class RelayService {
  WebSocketChannel? _channel;
  bool _connected = false;

  final _instanceController = StreamController<List<RelayInstance>>.broadcast();
  final _chunkController = StreamController<RelayChunk>.broadcast();

  bool get isConnected => _connected;
  Stream<List<RelayInstance>> get instances => _instanceController.stream;
  Stream<RelayChunk> get chunks => _chunkController.stream;

  /// Connect to a Relay server.
  Future<bool> connect(String url, {String? auth}) async {
    disconnect();

    try {
      final uri = Uri.parse(url);
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _connected = true;

      _channel!.stream.listen(
        _onMessage,
        onError: (e) {
          _connected = false;
        },
        onDone: () {
          _connected = false;
        },
      );

      // Request instance list
      _send({'type': 'list', if (auth != null) 'auth': auth});
      return true;
    } catch (_) {
      _connected = false;
      return false;
    }
  }

  /// Disconnect from Relay.
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _connected = false;
  }

  /// Send a chat message to a specific Hermes instance.
  void sendChat(String targetId, String content, String fromId) {
    _send({
      'type': 'chat',
      'target': targetId,
      'content': content,
      'from': fromId,
    });
  }

  void _send(Map<String, dynamic> msg) {
    if (_connected && _channel != null) {
      _channel!.sink.add(jsonEncode(msg));
    }
  }

  void _onMessage(dynamic data) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      final type = msg['type'] as String?;

      switch (type) {
        case 'instances':
          final list = (msg['list'] as List? ?? [])
              .map((j) => RelayInstance.fromJson(j))
              .toList();
          _instanceController.add(list);

        case 'chunk':
          _chunkController.add(RelayChunk(
            fromId: msg['from'] as String? ?? '',
            delta: msg['delta'] as String? ?? '',
            isDone: false,
          ));

        case 'done':
          _chunkController.add(RelayChunk(
            fromId: msg['from'] as String? ?? '',
            delta: '',
            isDone: true,
          ));

        case 'error':
          _chunkController.add(RelayChunk(
            fromId: '',
            delta: 'Error: ${msg['message'] ?? 'unknown'}',
            isDone: true,
          ));
      }
    } catch (_) {
      // Skip malformed messages
    }
  }

  void dispose() {
    disconnect();
    _instanceController.close();
    _chunkController.close();
  }
}

/// A Hermes instance discovered via Relay.
class RelayInstance {
  final String id;
  final String name;

  const RelayInstance({required this.id, required this.name});

  factory RelayInstance.fromJson(Map<String, dynamic> json) => RelayInstance(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Unknown',
      );
}

/// A streaming chunk from a relayed Hermes response.
class RelayChunk {
  final String fromId;
  final String delta;
  final bool isDone;

  const RelayChunk({
    required this.fromId,
    required this.delta,
    required this.isDone,
  });
}
