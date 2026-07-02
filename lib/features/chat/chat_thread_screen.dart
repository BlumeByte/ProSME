import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/widgets/loading_state.dart';
import '../../core/widgets/safe_back_button.dart';
import '../../config/constants.dart';
import '../../models/chat_models.dart';
import '../../models/wallet_transaction.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/service_providers.dart';
import '../../services/wallet_service.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _uuid = const Uuid();
  bool _sending = false;
  String? _editingMessageId;
  ChatMessage? _editingMessage;
  List<ChatMessage> _latestMessages = const [];
  final Set<String> _selectedMessageIds = {};

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final user = ref.read(authStateProvider).valueOrNull;
    final text = _controller.text.trim();
    if (_sending || user == null || text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final blocked = await ref.read(adminServiceProvider).isChatBlocked(
            threadId: widget.threadId,
            currentUserId: user.id,
          );
      if (blocked) {
        throw StateError('This chat is blocked.');
      }
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
      final settings = ref.read(appSettingsControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editingMessage == null
                ? settings.t('Could not send message. Please try again.')
                : settings.t('Could not update message. Please try again.'),
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

  bool get _selectingMessages => _selectedMessageIds.isNotEmpty;

  void _toggleMessageSelection(ChatMessage message) {
    setState(() {
      if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds.remove(message.id);
      } else {
        _selectedMessageIds.add(message.id);
      }
    });
  }

  void _selectAllMessages() {
    setState(() {
      _selectedMessageIds
        ..clear()
        ..addAll(_latestMessages.map((message) => message.id));
    });
  }

  void _clearSelection() {
    setState(() => _selectedMessageIds.clear());
  }

  Future<void> _deleteSelectedMessages() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || _selectedMessageIds.isEmpty) return;
    final ids = _selectedMessageIds.toList(growable: false);
    final settings = ref.read(appSettingsControllerProvider);
    try {
      await ref.read(chatServiceProvider).deleteMessagesForUser(
            threadId: widget.threadId,
            userId: user.id,
            messageIds: ids,
          );
      if (!mounted) return;
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ids.length} ${settings.t('message(s) deleted for you.')}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settings.t('Could not delete messages. Please try again.'),
          ),
        ),
      );
    }
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final settings = ref.read(appSettingsControllerProvider);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(settings.t('Delete message')),
        content:
            Text(settings.t('Are you sure you want to delete this message?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(settings.t('Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(chatServiceProvider).deleteMessage(
                      threadId: message.threadId,
                      messageId: message.id,
                      deletedForUserId: user.id,
                    );
                if (!mounted) return;
                if (_editingMessageId == message.id) _cancelEdit();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(settings.t('Message deleted.'))),
                );
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      settings.t('Could not delete message. Please try again.'),
                    ),
                  ),
                );
              }
            },
            child: Text(settings.t('Delete')),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllMessages() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final settings = ref.read(appSettingsControllerProvider);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(settings.t('Clear all messages')),
        content: Text(
          settings.t(
            'Are you sure you want to clear all messages in this conversation? This cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(settings.t('Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(chatServiceProvider).clearMessages(
                      widget.threadId,
                      clearedForUserId: user.id,
                    );
                if (!mounted) return;
                _cancelEdit();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(settings.t('Messages cleared.'))),
                );
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      settings.t('Could not clear messages. Please try again.'),
                    ),
                  ),
                );
              }
            },
            child: Text(settings.t('Clear')),
          ),
        ],
      ),
    );
  }

  Future<String> _resolveOtherUserId() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return '';
    for (final message in _latestMessages) {
      if (message.senderId != user.id) return message.senderId;
    }
    if (!shouldUseSupabase()) return '';
    try {
      final row = await ref
          .read(supabaseClientProvider)
          .from('threads')
          .select('user_id,artisan_id')
          .eq('id', widget.threadId)
          .maybeSingle();
      if (row == null) return '';
      final customerId = (row['user_id'] ?? '').toString();
      final artisanId = (row['artisan_id'] ?? '').toString();
      if (customerId == user.id) return artisanId;
      if (artisanId == user.id) return customerId;
    } catch (_) {}
    return '';
  }

  Future<bool> _shouldShowVerificationWarning() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || !shouldUseSupabase()) return false;
    final otherUserId = await _resolveOtherUserId();
    if (otherUserId.isEmpty || otherUserId == user.id) return false;
    try {
      final row = await ref
          .read(supabaseClientProvider)
          .from('profiles')
          .select('verification_status')
          .eq('id', otherUserId)
          .maybeSingle();
      final status = (row?['verification_status'] ?? '').toString();
      return status != 'verified';
    } catch (_) {
      return true;
    }
  }

  WalletTransaction? _invoiceFromMessage(ChatMessage message) {
    if (message.type != MessageType.invoice) return null;
    try {
      final payload = jsonDecode(message.content);
      if (payload is Map) {
        return WalletTransaction.fromJson(
          Map<String, dynamic>.from(payload),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<void> _openInvoiceCenter() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || _sending) return;
    final settings = ref.read(appSettingsControllerProvider);
    setState(() => _sending = true);
    try {
      List<WalletTransaction> invoices;
      if (user.role == UserRole.artisan) {
        final otherUserId = await _resolveOtherUserId();
        final all = shouldUseSupabase()
            ? await WalletService(ref.read(supabaseClientProvider))
                .loadTransactions(userId: user.id, role: user.role)
            : _latestMessages
                .map(_invoiceFromMessage)
                .whereType<WalletTransaction>()
                .toList(growable: false);
        invoices = all
            .where(
              (item) =>
                  item.artisanId == user.id &&
                  (otherUserId.isEmpty || item.customerId == otherUserId),
            )
            .toList(growable: false);
      } else {
        invoices = _latestMessages
            .map(_invoiceFromMessage)
            .whereType<WalletTransaction>()
            .toList(growable: false);
      }
      if (!mounted) return;
      if (invoices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              settings.t(
                user.role == UserRole.artisan
                    ? 'No accepted-work invoice is available for this chat.'
                    : 'No invoice has been sent in this chat yet.',
              ),
            ),
          ),
        );
        return;
      }

      final selected = await showModalBottomSheet<WalletTransaction>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            itemCount: invoices.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final invoice = invoices[index];
              return ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(invoice.jobTitle),
                subtitle: Text(
                  '${invoice.invoiceNumber}\n${invoice.currency} ${invoice.amount.toStringAsFixed(2)}',
                ),
                isThreeLine: true,
                trailing: Icon(
                  user.role == UserRole.artisan
                      ? Icons.send_outlined
                      : Icons.open_in_new,
                ),
                onTap: () => Navigator.pop(context, invoice),
              );
            },
          ),
        ),
      );
      if (selected == null || !mounted) return;
      if (user.role == UserRole.artisan) {
        await _sendInvoiceMessage(selected);
      } else {
        context.push(RouteNames.invoice, extra: selected);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${settings.t('Could not load invoice')}: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendInvoiceMessage(WalletTransaction transaction) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    await ref.read(chatServiceProvider).sendMessage(
          ChatMessage(
            id: _uuid.v4(),
            threadId: widget.threadId,
            senderId: user.id,
            type: MessageType.invoice,
            content: jsonEncode(transaction.toJson()),
            createdAt: DateTime.now(),
          ),
        );
    if (!mounted) return;
    final settings = ref.read(appSettingsControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(settings.t('Invoice sent to chat.'))),
    );
  }

  Future<String?> _promptReason({
    required String title,
    required String label,
  }) async {
    final settings = ref.read(appSettingsControllerProvider);
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.t(title)),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(labelText: settings.t(label)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(settings.t('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(settings.t('Submit')),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _reportConversation() async {
    final settings = ref.read(appSettingsControllerProvider);
    final reason = await _promptReason(
      title: 'Report chat',
      label: 'What should the admin review?',
    );
    if (reason == null || reason.trim().isEmpty) return;
    final reportedUserId = await _resolveOtherUserId();
    try {
      await ref.read(adminServiceProvider).submitChatReport(
            threadId: widget.threadId,
            reportedUserId: reportedUserId,
            reason: reason,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.t('Report sent to Admin Dashboard.')),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${settings.t('Could not send report')}: $error')),
      );
    }
  }

  Future<void> _blockConversation() async {
    final settings = ref.read(appSettingsControllerProvider);
    final otherUserId = await _resolveOtherUserId();
    if (otherUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('Could not find the other user.'))),
      );
      return;
    }
    final reason = await _promptReason(
      title: 'Block chat',
      label: 'Reason for blocking',
    );
    if (reason == null) return;
    try {
      await ref.read(adminServiceProvider).blockChatUser(
            threadId: widget.threadId,
            blockedUserId: otherUserId,
            reason: reason,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('Chat blocked and reported.'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${settings.t('Could not block chat')}: $error')),
      );
    }
  }

  Future<void> _copyMessage(ChatMessage message) async {
    await Clipboard.setData(ClipboardData(text: message.threadPreview));
    if (!mounted) return;
    final settings = ref.read(appSettingsControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(settings.t('Message copied.'))),
    );
  }

  Future<void> _viewProfile(String userId) async {
    Map<String, dynamic>? profile;
    if (shouldUseSupabase()) {
      try {
        final row = await ref
            .read(supabaseClientProvider)
            .from('profiles')
            .select(
              'id,username,full_name,avatar_url,description,role,verification_status',
            )
            .eq('id', userId)
            .maybeSingle();
        if (row != null) profile = Map<String, dynamic>.from(row);
      } catch (_) {}
    }
    if (!mounted) return;
    final settings = ref.read(appSettingsControllerProvider);
    final name = (profile?['username'] ?? profile?['full_name'] ?? 'User')
        .toString()
        .trim();
    final avatarUrl = (profile?['avatar_url'] ?? '').toString();
    final description = (profile?['description'] ?? '').toString().trim();
    final role = (profile?['role'] ?? '').toString();
    final verified =
        (profile?['verification_status'] ?? '').toString() == 'verified';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          settings
              .t(role == 'artisan' ? 'Professional profile' : 'User profile'),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                foregroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                onForegroundImageError:
                    avatarUrl.isNotEmpty ? (_, __) {} : null,
                child: const Icon(Icons.person, size: 40),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      name.isEmpty ? settings.t('User') : name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (verified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, color: Colors.blue, size: 18),
                  ],
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(description, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
        actions: [
          if (role == 'artisan')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('${RouteNames.artisanProfile}/$userId');
              },
              child: Text(settings.t('View full profile')),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(settings.t('Close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatService = ref.watch(chatServiceProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final settings = ref.watch(appSettingsControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: _selectingMessages
            ? IconButton(
                onPressed: _clearSelection,
                icon: const Icon(Icons.close),
              )
            : const SafeBackButton(),
        title: Text(
          _selectingMessages
              ? '${_selectedMessageIds.length}'
              : settings.t('Chat'),
        ),
        actions: _selectingMessages
            ? [
                IconButton(
                  onPressed: _selectAllMessages,
                  icon: const Icon(Icons.select_all),
                  tooltip: settings.t('Select all'),
                ),
                IconButton(
                  onPressed: _deleteSelectedMessages,
                  icon: const Icon(Icons.delete),
                  tooltip: settings.t('Delete selected'),
                ),
              ]
            : [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'clear_all') {
                      _clearAllMessages();
                    } else if (value == 'report') {
                      _reportConversation();
                    } else if (value == 'block') {
                      _blockConversation();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'clear_all',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_sweep),
                          const SizedBox(width: 8),
                          Text(settings.t('Clear all messages')),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          const Icon(Icons.report_gmailerrorred_outlined),
                          const SizedBox(width: 8),
                          Text(settings.t('Report')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          const Icon(Icons.block),
                          const SizedBox(width: 8),
                          Text(settings.t('Block')),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
      ),
      body: Column(
        children: [
          FutureBuilder<bool>(
            future: _shouldShowVerificationWarning(),
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return Material(
                color: colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          settings.t(
                            'This account is not verified. Be cautious before sharing payments or personal details.',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: chatService.watchMessages(
                widget.threadId,
                userId: user?.id,
              ),
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
                            settings.t(
                              'Could not load messages. Please check your connection and try again.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return LoadingState(label: settings.t('Loading messages...'));
                }

                final messages = _sortMessages(snapshot.data!);
                _latestMessages = messages;
                _scrollToBottom();
                if (user != null &&
                    messages.any((message) =>
                        message.senderId != user.id &&
                        message.readAt == null)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    ref
                        .read(chatServiceProvider)
                        .markThreadRead(widget.threadId, user.id);
                  });
                }
                if (messages.isEmpty) {
                  return Center(
                      child: Text(settings.t('Start the conversation.')));
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: false,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final invoice = _invoiceFromMessage(message);
                    final previous = index == 0 ? null : messages[index - 1];
                    final showDateHeader = previous == null ||
                        !_isSameDay(previous.createdAt, message.createdAt);
                    final isMine = user?.id == message.senderId;
                    final isSelected = _selectedMessageIds.contains(message.id);
                    return Column(
                      children: [
                        if (showDateHeader)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10, top: 2),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                child: Text(
                                  _formatDayHeader(message.createdAt),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                            ),
                          ),
                        Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: InkWell(
                            onLongPress: () => _toggleMessageSelection(message),
                            onTap: _selectingMessages
                                ? () => _toggleMessageSelection(message)
                                : invoice != null
                                    ? () => context.push(
                                          RouteNames.invoice,
                                          extra: invoice,
                                        )
                                    : (!isMine
                                        ? () => _viewProfile(message.senderId)
                                        : () => _showMessageOptions(
                                            context, message)),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * 0.76,
                              ),
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? colorScheme.primary
                                    : colorScheme.surfaceContainerHighest,
                                border: isSelected
                                    ? Border.all(
                                        color: colorScheme.secondary,
                                        width: 2,
                                      )
                                    : null,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(14),
                                  topRight: const Radius.circular(14),
                                  bottomLeft: Radius.circular(isMine ? 14 : 4),
                                  bottomRight: Radius.circular(isMine ? 4 : 14),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (message.content.startsWith(
                                      '${settings.t('Forwarded from chat')}:')) ...[
                                    Text(
                                      settings.t('Forwarded'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: isMine
                                                ? colorScheme.onPrimary
                                                    .withValues(alpha: 0.75)
                                                : colorScheme.onSurfaceVariant,
                                            fontStyle: FontStyle.italic,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  if (invoice != null)
                                    _InvoiceChatBubble(
                                      transaction: invoice,
                                      isMine: isMine,
                                      settings: settings,
                                    )
                                  else
                                    Text(
                                      message.content.replaceFirst(
                                        '${settings.t('Forwarded from chat')}:\n',
                                        '',
                                      ),
                                      style: TextStyle(
                                        color: isMine
                                            ? colorScheme.onPrimary
                                            : colorScheme.onSurface,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      _formatTime(message),
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
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.edit, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        settings.t('Editing message'),
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
                        SnackBar(
                          content: Text(
                            settings.t(
                              'Location sharing will be added after map permissions are configured.',
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.location_on),
                    tooltip: settings.t('Share location'),
                  ),
                  IconButton(
                    onPressed: _sending ? null : _openInvoiceCenter,
                    icon: const Icon(Icons.receipt_long),
                    tooltip: settings.t('Invoice'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: _editingMessageId == null
                            ? settings.t('Message')
                            : settings.t('Edit message'),
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
                    tooltip: settings.t(
                      _editingMessageId == null ? 'Send' : 'Save edit',
                    ),
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
    final settings = ref.read(appSettingsControllerProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.type == MessageType.text)
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(settings.t('Edit message')),
                onTap: () {
                  Navigator.pop(context);
                  _startEditMessage(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(settings.t('Copy message')),
              onTap: () {
                Navigator.pop(context);
                _copyMessage(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: Text(settings.t('Delete message')),
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

  List<ChatMessage> _sortMessages(List<ChatMessage> messages) {
    return List<ChatMessage>.from(messages)
      ..sort((a, b) {
        final byCreatedAt = a.createdAt.compareTo(b.createdAt);
        if (byCreatedAt != 0) return byCreatedAt;
        return a.id.compareTo(b.id);
      });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDayHeader(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dateTime.year, dateTime.month, dateTime.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEEE, MMM d, y').format(dateTime);
  }

  String _formatTime(ChatMessage message) {
    final edited =
        message.updatedAt.difference(message.createdAt).inSeconds > 2;
    return '${edited ? 'Edited ' : ''}${DateFormat('h:mm a').format(message.createdAt)}';
  }
}

class _InvoiceChatBubble extends StatelessWidget {
  const _InvoiceChatBubble({
    required this.transaction,
    required this.isMine,
    required this.settings,
  });

  final WalletTransaction transaction;
  final bool isMine;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isMine ? colorScheme.onPrimary : colorScheme.onSurface;
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_outlined, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  settings.t('Invoice'),
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            transaction.jobTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color),
          ),
          const SizedBox(height: 4),
          Text(
            '${transaction.currency} ${transaction.amount.toStringAsFixed(2)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            settings.t('Tap to view, print, or share PDF'),
            style:
                TextStyle(color: color.withValues(alpha: 0.78), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
