import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final tree = chat.tree;

    return Scaffold(
      appBar: AppBar(title: const Text('Conversations')),
      floatingActionButton: PopupMenuButton<String>(
        icon: const Icon(Icons.add),
        onSelected: (action) async {
          if (action == 'folder') {
            _showCreateFolderDialog();
          } else {
            final conv = await chat.newConversation();
            if (mounted) {
              Navigator.pop(context);
              _openConversation(conv.id);
            }
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'folder', child: ListTile(leading: Icon(Icons.create_new_folder), title: Text('New Folder'))),
          PopupMenuItem(value: 'chat', child: ListTile(leading: Icon(Icons.chat), title: Text('New Chat'))),
        ],
      ),
      body: tree.isEmpty
          ? const Center(child: Text('No conversations yet.\nTap + to start.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              itemCount: tree.length,
              itemBuilder: (_, i) => _TreeTile(node: tree[i], chat: chat),
            ),
    );
  }

  Future<void> _openConversation(String convId) async {
    final chat = context.read<ChatProvider>();
    final serverId = await chat.getConversationServer(convId);

    if (!mounted) return;

    // Auto-switch server if needed
    if (serverId != null) {
      final settings = context.read<SettingsProvider>();
      if (settings.activeServer?.id != serverId) {
        settings.setActiveServer(serverId);
        final server = settings.activeServer;
        if (server != null) {
          chat.switchServer(baseUrl: server.baseUrl, apiKey: server.apiKey);
        }
      }
    }

    await chat.loadConversation(convId);
  }

  Future<void> _showCreateFolderDialog({String? parentId}) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Folder name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && mounted) {
      context.read<ChatProvider>().createFolder(name: name, parentId: parentId);
    }
  }
}

class _TreeTile extends StatefulWidget {
  final TreeNode node;
  final ChatProvider chat;

  const _TreeTile({required this.node, required this.chat});

  @override
  State<_TreeTile> createState() => _TreeTileState();
}

class _TreeTileState extends State<_TreeTile> {
  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final theme = Theme.of(context);

    if (node.isFolder) {
      final folder = node.folder!;
      final indent = 16.0 * node.depth;
      return Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.only(left: indent + 16),
            leading: Icon(node.isExpanded ? Icons.folder_open : Icons.folder,
                color: theme.colorScheme.primary),
            title: Text(folder.name, style: const TextStyle(fontWeight: FontWeight.w500)),
            onTap: () => setState(() => node.isExpanded = !node.isExpanded),
            onLongPress: () => _showFolderMenu(folder),
          ),
          if (node.isExpanded)
            ..._children().map((child) => Builder(
                  builder: (ctx) => _TreeTile(node: child, chat: widget.chat),
                )),
        ],
      );
    } else {
      final conv = node.conversation!;
      final isActive = conv.id == widget.chat.activeConversationId;
      final indent = 16.0 * node.depth;

      return ListTile(
        contentPadding: EdgeInsets.only(left: indent + 16),
        leading: Icon(
          isActive ? Icons.chat_bubble : Icons.chat_bubble_outline,
          color: isActive ? theme.colorScheme.primary : null,
          size: 20,
        ),
        title: Text(conv.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${conv.messageCount} msgs${conv.serverId != null ? "  ·  bound" : ""}',
            style: const TextStyle(fontSize: 11)),
        selected: isActive,
        onTap: () {
          final convId = conv.id;
          final state = context.findAncestorStateOfType<_ConversationsScreenState>();
          state?._openConversation(convId);
          Navigator.pop(context);
        },
        onLongPress: () => _showConvMenu(conv),
      );
    }
  }

  List<TreeNode> _children() {
    // Find child nodes after this folder until the next node at same or lesser depth
    final idx = widget.chat.tree.indexOf(widget.node);
    final result = <TreeNode>[];
    for (int i = idx + 1; i < widget.chat.tree.length; i++) {
      final child = widget.chat.tree[i];
      if (child.depth <= widget.node.depth) break;
      if (child.depth == widget.node.depth + 1) result.add(child);
    }
    return result;
  }

  void _showFolderMenu(folder) {
    final ctrl = TextEditingController(text: folder.name);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.edit), title: const Text('Rename'), onTap: () async {
            Navigator.pop(ctx);
            final name = await showDialog<String>(context: context, builder: (c) => AlertDialog(
              title: const Text('Rename'), content: TextField(controller: ctrl, autofocus: true),
              actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('OK'))],
            ));
            if (name != null && name.isNotEmpty) widget.chat.renameFolder(folder.id, name);
          }),
          ListTile(leading: const Icon(Icons.create_new_folder), title: const Text('New Subfolder'), onTap: () {
            Navigator.pop(ctx);
            context.findAncestorStateOfType<_ConversationsScreenState>()?._showCreateFolderDialog(parentId: folder.id);
          }),
          ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Delete', style: TextStyle(color: Colors.red)), onTap: () {
            Navigator.pop(ctx);
            widget.chat.deleteFolder(folder.id);
          }),
        ]),
      ),
    );
  }

  void _showConvMenu(conv) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.drive_file_move), title: const Text('Move to...'), onTap: () {
            Navigator.pop(ctx);
            _showMoveDialog(conv.id);
          }),
          ListTile(leading: const Icon(Icons.edit), title: const Text('Rename'), onTap: () async {
            Navigator.pop(ctx);
            final ctrl = TextEditingController(text: conv.title);
            final name = await showDialog<String>(context: context, builder: (c) => AlertDialog(
              title: const Text('Rename'), content: TextField(controller: ctrl, autofocus: true),
              actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('OK'))],
            ));
            if (name != null && name.isNotEmpty) widget.chat.renameConversation(conv.id, name);
          }),
          ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Delete', style: TextStyle(color: Colors.red)), onTap: () {
            Navigator.pop(ctx);
            widget.chat.deleteConversation(conv.id);
          }),
        ]),
      ),
    );
  }

  void _showMoveDialog(String convId) {
    final folders = widget.chat.folders;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(shrinkWrap: true, children: [
            ListTile(title: const Text('(No folder)'), onTap: () {
              widget.chat.moveConversation(convId, null);
              Navigator.pop(ctx);
            }),
            ...folders.map((f) => ListTile(title: Text(f.name), onTap: () {
              widget.chat.moveConversation(convId, f.id);
              Navigator.pop(ctx);
            })),
          ]),
        ),
      ),
    );
  }
}
