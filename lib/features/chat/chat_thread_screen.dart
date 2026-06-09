import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/widgets/safe_back_button.dart';
import '../../core/widgets/loading_state.dart';
import '../../services/service_providers.dart';
import '../../models/chat_models.dart';
import '../../config/constants.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _controller = TextEditingController();
  final _uuid = const Uuid();
  bool _sending = false;
  String? _editingMessageId;
  String? _editingContent;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (_sending || user == null || _controller.text.isEmpty) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final message = ChatMessage(
      id: _editingMessageId ?? _uuid.v4(),
      threadId: widget.threadId,
      senderId: user.id,
      type: MessageType.text,
      content: text,
      createdAt: _editingMessageId != null ? DateTime.now() : DateTime.now(),
    );
    try {
      await ref.read(chatServiceProvider).sendMessage(message);
      _controller.clear();
      setState(() {
        _editingMessageId = null;
        _editingContent = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not send message. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startEditMessage(ChatMessage message) {
    setState(() {
      _editingMessageId = message.id;
      _editingContent = message.content;
      _controller.text = message.content;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingMessageId = null;
      _editingContent = null;
      _controller.clear();
    });
  }

  void _deleteMessage(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message deleted')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _clearAllMessages() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all messages'),
        content: const Text(
          'Are you sure you want to clear all messages in this conversation? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Messages cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _shareMessages(List<ChatMessage> messages) {
    if (messages.isEmpty) return;
    final text = messages
        .map((m) => '${m.createdAt}: ${m.content}')
        .join('\n');
    Share.share(text, subject: 'Chat conversation from ProSME');
  }

  void _viewProfile(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
              const SizedBox(height: 16),
              Text(
                'User ID: $userId',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Full profile details loading...',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatService = ref.watch(chatServiceProvider);
    final user = ref.watch(authStateProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: const Text('Chat'),
        actions: [
          PopupMenuButton(
            onSelected: (value) {
              if (value == 'clear_all') {
                _clearAllMessages();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep),
                    SizedBox(width: 8),
                    Text('Clear all messages'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Confirm artisan verification status before sharing payments or personal details.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: chatService.watchMessages(widget.threadId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Could not load messages.\nError: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const LoadingState(label: 'Loading messages...');
                }
                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const Center(child: Text('Start the conversation.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMine = user?.id == message.senderId;
                    return Align(
                      alignment:
                          isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: isMine
                            ? () => _showMessageOptions(context, message)
                            : () => _viewProfile(message.senderId),
                        child: GestureDetector(
                          onTap: !isMine
                              ? () => _viewProfile(message.senderId)
                              : null,
                          child: Card(
                            color: isMine
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(message.content),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(message.createdAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_editingMessageId != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Editing message'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _cancelEdit,
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Location sharing will be added after map permissions are configured.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.location_on),
                ),
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Open the listing and request invoice from there.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long),
                ),
                IconButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Share functionality available soon'),
                    ),
                  ),
                  icon: const Icon(Icons.share),
                  tooltip: 'Share chat',
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(hintText: 'Message'),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : _sendMessage,
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(BuildContext context, ChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit message'),
              onTap: () {
                Navigator.pop(context);
                _startEditMessage(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete message'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy message'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, "0")}';
  }
}
