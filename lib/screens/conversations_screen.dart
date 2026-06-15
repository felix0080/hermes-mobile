import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final conversations = chat.conversations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              chat.newConversation();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: conversations.isEmpty
          ? const Center(
              child: Text('No conversations yet', style: TextStyle(color: Colors.grey)),
            )
          : ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (_, i) {
                final conv = conversations[i];
                final isActive = conv.id == chat.activeConversationId;
                return Dismissible(
                  key: Key(conv.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => chat.deleteConversation(conv.id),
                  child: ListTile(
                    leading: Icon(
                      isActive ? Icons.chat_bubble : Icons.chat_bubble_outline,
                      color: isActive ? Theme.of(context).colorScheme.primary : null,
                    ),
                    title: Text(
                      conv.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${conv.messageCount} messages • ${_formatDate(conv.updatedAt)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      chat.loadConversation(conv.id);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day}';
  }
}
