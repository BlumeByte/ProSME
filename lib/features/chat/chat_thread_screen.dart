import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/widgets/loading_state.dart';
import '../../core/widgets/safe_back_button.dart';
import '../../models/chat_models.dart';
import '../../services/service_providers.dart';

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
  ChatMessage? _editingMessage;
  List<ChatMessage> _latestMessages = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final user = ref.read(authStateProvider).valueOrNull;
    final text = _controller.text.trim();
    if (_sending || user == null || text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final chatService = ref.read(chatServiceProvider);
      if (_editingMessage != null) {
        await chatService.updateMessage(
          _editingMessage!.copyWith(content: text),
        );
      } else {
        await chatService.sendMessage(
          ChatMessage(
            id: _uuid.v4(),
            threadId: widget.threadId,
            senderId: user.id,
            type: MessageType.text,
            content: text,
            createdAt: DateTime.now(),
          ),
        );
      }
      _controller.clear();
      setState(() {
        _editingMessageId = null;
        _editingMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editingMessage == null
                ? 'Could not send message. Please try again.'
                : 'Could not update message: $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startEditMessage(ChatMessage message) {
    setState(() {
      _editingMessageId = message.id;
      _editingMessage = message;
      _controller.text = message.content;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingMessageId = null;
      _editingMessage = null;
      _controller.clear();
    });
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    await showDialog<void>(
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
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(chatServiceProvider).deleteMessage(
                      threadId: message.threadId,
                      messageId: message.id,
                    );
                if (!mounted) return;
                if (_editingMessageId == message.id) _cancelEdit();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message deleted.')),
                );
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not delete message: $error')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllMessages() async {
    await showDialog<void>(
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
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(chatServiceProvider).clearMessages(
                      widget.threadId,
                    );
                if (!mounted) return;
                _cancelEdit();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Messages cleared.')),
                );
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not clear messages: $error')),
                );
              }
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  String _messagesShareText(List<ChatMessage> messages) {
    return messages
        .map(
          (message) =>
              '${DateFormat('MMM d, h:mm a').format(message.createdAt)}: ${message.content}',
        )
        .join('\n');
  }

  Future<void> _shareMessages(List<ChatMessage> messages) async {
    if (messages.isEmpty) return;
    await Share.share(
      _messagesShareText(messages),
      subject: 'Chat conversation from ProSME',
    );
  }

  Future<void> _shareBySms(List<ChatMessage> messages) async {
    if (messages.isEmpty) return;
    final uri = Uri(
      scheme: 'sms',
      queryParameters: {'body': _messagesShareText(messages)},
    );
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open SMS app.')),
      );
    }
  }

  Future<void> _copyMessage(ChatMessage message) async {
    await Clipboard.setData(ClipboardData(text: message.content));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied.')),
    );
  }

  void _showShareOptions(List<ChatMessage> messages) {
    if (messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No messages to share yet.')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Share to phone app'),
              onTap: () {
                Navigator.pop(context);
                _shareMessages(messages);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: const Text('Send as SMS'),
              onTap: () {
                Navigator.pop(context);
                _shareBySms(messages);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Forward to another chat'),
              onTap: () {
                Navigator.pop(context);
                _chooseForwardThread(messages);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _chooseForwardThread(List<ChatMessage> messages) {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forward to chat'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<ChatThread>>(
            stream: ref.read(chatServiceProvider).watchThreads(user.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final threads = snapshot.data!
                  .where((thread) => thread.id != widget.threadId)
                  .toList(growable: false);
              if (threads.isEmpty) {
                return const Text('No other chats available.');
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: threads.length,
                itemBuilder: (context, index) {
                  final thread = threads[index];
                  return ListTile(
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text(_threadTitle(thread, user.id)),
                    subtitle: Text(
                      thread.lastMessage.isEmpty
                          ? 'No messages yet'
                          : thread.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _forwardMessages(thread.id, messages);
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _forwardMessages(
    String targetThreadId,
    List<ChatMessage> messages,
  ) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || messages.isEmpty) return;

    try {
      await ref.read(chatServiceProvider).sendMessage(
            ChatMessage(
              id: _uuid.v4(),
              threadId: targetThreadId,
              senderId: user.id,
              type: MessageType.text,
              content: 'Forwarded from chat:\n${_messagesShareText(messages)}',
              createdAt: DateTime.now(),
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Forwarded to chat.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not forward message: $error')),
      );
    }
  }

  void _viewProfile(String userId) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 40,
                child: Icon(Icons.person, size: 40),
              ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: const Text('Chat'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_all') {
                _clearAllMessages();
              } else if (value == 'share') {
                _showShareOptions(_latestMessages);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.ios_share),
                    SizedBox(width: 8),
                    Text('Share conversation'),
                  ],
                ),
              ),
              PopupMenuItem(
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
            color: colorScheme.surfaceContainerHighest,
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
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
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
                _latestMessages = messages;
                if (messages.isEmpty) {
                  return const Center(child: Text('Start the conversation.'));
                }
                final displayMessages = messages.reversed.toList(growable: false);

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: displayMessages.length,
                  itemBuilder: (context, index) {
                    final message = displayMessages[index];
                    final isMine = user?.id == message.senderId;
                    return Align(
                      alignment:
                          isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: InkWell(
                        onLongPress: isMine
                            ? () => _showMessageOptions(context, message)
                            : () => _viewProfile(message.senderId),
                        onTap: !isMine
                            ? () => _viewProfile(message.senderId)
                            : null,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                          ),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMine
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.content,
                                style: TextStyle(
                                  color: isMine
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(message.createdAt),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: isMine
                                          ? colorScheme.onPrimary
                                              .withValues(alpha: 0.75)
                                          : colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
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
            Material(
              color: colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.edit, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Editing message',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _cancelEdit,
                    ),
                  ],
                ),
              ),
            ),
          Material(
            color: colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Location sharing will be added after map permissions are configured.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.location_on),
                    tooltip: 'Share location',
                  ),
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Open the listing and request invoice from there.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.receipt_long),
                    tooltip: 'Invoice',
                  ),
                  IconButton(
                    onPressed: () => _showShareOptions(_latestMessages),
                    icon: const Icon(Icons.ios_share),
                    tooltip: 'Share chat',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: _editingMessageId == null
                            ? 'Message'
                            : 'Edit message',
                      ),
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
                        : Icon(
                            _editingMessageId == null
                                ? Icons.send
                                : Icons.check,
                          ),
                    tooltip: _editingMessageId == null ? 'Send' : 'Save edit',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(BuildContext context, ChatMessage message) {
    showModalBottomSheet<void>(
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
              leading: const Icon(Icons.ios_share),
              title: const Text('Share message'),
              onTap: () {
                Navigator.pop(context);
                _showShareOptions([message]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy message'),
              onTap: () {
                Navigator.pop(context);
                _copyMessage(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete message'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _threadTitle(ChatThread thread, String currentUserId) {
    final isUser = thread.userId == currentUserId;
    final title = isUser ? thread.artisanName : thread.userName;
    if (title != null && title.trim().isNotEmpty) return title;
    return isUser ? 'Artisan chat' : 'Customer chat';
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }
}
