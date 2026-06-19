import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final theme = Theme.of(context);
    final hasImages = message.imagePaths.isNotEmpty;

    final bubble = Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: message.isStreaming && message.content.isEmpty
            ? const SizedBox(width: 24, height: 16,
                child: Center(child: SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Images
                  if (hasImages) ...[
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: message.imagePaths.map((path) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(path),
                            width: 120, height: 120, fit: BoxFit.cover),
                      )).toList(),
                    ),
                    if (message.content.isNotEmpty) const SizedBox(height: 8),
                  ],
                  // Text
                  if (message.content.isNotEmpty)
                    isUser
                        ? SelectableText(message.content,
                            style: TextStyle(color: theme.colorScheme.onPrimaryContainer))
                        : MarkdownBody(
                            data: message.content,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(color: theme.colorScheme.onSurface),
                              code: TextStyle(backgroundColor: theme.colorScheme.surfaceContainer,
                                  fontFamily: 'monospace', fontSize: 13),
                            ),
                          ),
                ],
              ),
      ),
    );

    if (message.isStreaming) return bubble;

    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: bubble,
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.copy), title: const Text('Copy'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.content));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
            }),
          if (onRetry != null)
            ListTile(leading: const Icon(Icons.refresh), title: const Text('Retry'),
              onTap: () { Navigator.pop(ctx); onRetry!.call(); }),
          if (onDelete != null)
            ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(ctx); onDelete!.call(); }),
        ]),
      ),
    );
  }
}
