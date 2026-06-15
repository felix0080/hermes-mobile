import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final theme = Theme.of(context);

    return Align(
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
            ? const SizedBox(
                width: 24,
                height: 16,
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : isUser
                ? SelectableText(
                    message.content,
                    style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                  )
                : MarkdownBody(
                    data: message.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(color: theme.colorScheme.onSurface),
                      code: TextStyle(
                        backgroundColor: theme.colorScheme.surfaceContainer,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
      ),
    );
  }
}
