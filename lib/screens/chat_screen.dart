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
    // Sync API config
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      context.read<ChatProvider>().updateApiConfig(
            baseUrl: settings.baseUrl,
            apiKey: settings.apiKey,
          );
    });
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hermes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/conversations'),
            tooltip: 'Conversations',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chat.messages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
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
                    itemBuilder: (_, i) =>
                        MessageBubble(message: chat.messages[i]),
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
            isLoading: chat.isLoading,
            isListening: chat.isListening,
          ),
        ],
      ),
    );
  }
}
