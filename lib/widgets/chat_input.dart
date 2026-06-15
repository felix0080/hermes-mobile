import 'package:flutter/material.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSend;
  final VoidCallback? onVoiceInput;
  final bool isLoading;
  final bool isListening;

  const ChatInput({
    super.key,
    required this.onSend,
    this.onVoiceInput,
    required this.isLoading,
    required this.isListening,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isLoading) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (widget.onVoiceInput != null)
            IconButton(
              icon: Icon(
                widget.isListening ? Icons.mic : Icons.mic_none,
                color: widget.isListening ? Colors.red : null,
              ),
              onPressed: widget.isLoading ? null : widget.onVoiceInput,
              tooltip: 'Voice input',
            ),
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: 5,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Message Hermes...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                isDense: true,
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: widget.isLoading
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 48,
                    height: 48,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton(
                    key: const ValueKey('send'),
                    icon: Icon(
                      _hasText ? Icons.send_rounded : Icons.send_outlined,
                    ),
                    color: _hasText
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    onPressed: _hasText ? _send : null,
                    tooltip: 'Send',
                  ),
          ),
        ],
      ),
    );
  }
}
