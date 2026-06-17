import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncServerConfig();
    });
  }

  void _syncServerConfig() {
    final settings = context.read<SettingsProvider>();
    final server = settings.activeServer;
    if (server != null) {
      final chat = context.read<ChatProvider>();
      chat.switchServer(
        baseUrl: server.baseUrl,
        apiKey: server.apiKey,
      );
      chat.checkConnection();
      chat.init();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: chat.isConnected ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Hermes'),
            if (settings.servers.length > 1) ...[
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                initialValue: settings.activeServer?.id,
                onSelected: (id) {
                  settings.setActiveServer(id);
                  _syncServerConfig();
                },
                itemBuilder: (_) => settings.servers.map((s) {
                  final isActive = s.id == settings.activeServer?.id;
                  return PopupMenuItem<String>(
                    value: s.id,
                    child: Row(
                      children: [
                        Icon(
                          isActive ? Icons.radio_button_checked : Icons.radio_button_off,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(s.name),
                      ],
                    ),
                  );
                }).toList(),
                child: Chip(
                  label: Text(
                    settings.activeServer?.name ?? 'No server',
                    style: const TextStyle(fontSize: 12),
                  ),
                  avatar: const Icon(Icons.dns, size: 14),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment),
            onPressed: () => chat.newConversation(),
            tooltip: 'New chat',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/conversations'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chat.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        if (settings.activeServer != null)
                          Text(
                            'Connected to ${settings.activeServer!.name}',
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        const SizedBox(height: 4),
                        const Text(
                          'Start a conversation',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: chat.messages.length,
                    itemBuilder: (_, i) => MessageBubble(
                      message: chat.messages[i],
                      onRetry: () => chat.retryLastMessage(),
                      onDelete: () => chat.deleteMessage(chat.messages[i].id),
                    ),
                  ),
          ),
          ChatInput(
            onSend: (text) {
              chat.sendMessage(text);
              _scrollToBottom();
            },
            onVoiceInput: () async {
              final text = await chat.startListening();
              if (text != null && text.isNotEmpty && mounted) {
                chat.sendMessage(text);
                _scrollToBottom();
              }
            },
            onCancel: () => chat.cancelStreaming(),
            isLoading: chat.isLoading,
            isListening: chat.isListening,
          ),
        ],
      ),
    );
  }
}
