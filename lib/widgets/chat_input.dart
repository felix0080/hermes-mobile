import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ChatInput extends StatefulWidget {
  final Function(String text, List<String> imagePaths) onSend;
  final VoidCallback? onVoiceInput;
  final VoidCallback? onCancel;
  final bool isLoading;
  final bool isListening;

  const ChatInput({
    super.key,
    required this.onSend,
    this.onVoiceInput,
    this.onCancel,
    required this.isLoading,
    required this.isListening,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  final List<String> _imagePaths = [];
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024);
    if (file != null) {
      setState(() => _imagePaths.add(file.path));
    }
  }

  void _showImageSource() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Camera'),
            onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); }),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Gallery'),
            onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); }),
        ]),
      ),
    );
  }

  void _send() {
    final text = _controller.text.trim();
    if ((text.isEmpty && _imagePaths.isEmpty) || widget.isLoading) return;
    widget.onSend(text, List<String>.from(_imagePaths));
    _controller.clear();
    _imagePaths.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 8, top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image previews
          if (_imagePaths.isNotEmpty)
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _imagePaths.length,
                separatorBuilder: (_, __) => const SizedBox(width: 4),
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(_imagePaths[i]), width: 64, height: 64, fit: BoxFit.cover),
                    ),
                    Positioned(top: 0, right: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _imagePaths.removeAt(i)),
                        child: Container(
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.add_photo_alternate_outlined),
                onPressed: widget.isLoading ? null : _showImageSource,
                tooltip: 'Attach image',
              ),
              if (widget.onVoiceInput != null)
                IconButton(
                  icon: Icon(widget.isListening ? Icons.mic : Icons.mic_none,
                      color: widget.isListening ? Colors.red : null),
                  onPressed: widget.isLoading ? null : widget.onVoiceInput,
                  tooltip: 'Voice input',
                ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: 5, minLines: 1,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'Message Hermes...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
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
                    ? IconButton(key: const ValueKey('stop'), icon: const Icon(Icons.stop_rounded),
                        color: Colors.red, onPressed: widget.onCancel, tooltip: 'Stop')
                    : IconButton(key: const ValueKey('send'),
                        icon: Icon(_hasText || _imagePaths.isNotEmpty ? Icons.send_rounded : Icons.send_outlined),
                        color: (_hasText || _imagePaths.isNotEmpty)
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        onPressed: (_hasText || _imagePaths.isNotEmpty) ? _send : null,
                        tooltip: 'Send'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
