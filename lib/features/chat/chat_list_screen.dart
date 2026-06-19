import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/loading_state.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/service_providers.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  Future<void> _deleteThread(
    BuildContext context,
    WidgetRef ref,
    String threadId,
    String userId,
  ) async {
    final settings = ref.read(appSettingsControllerProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.t('Delete chat')),
        content:
            Text(settings.t('Delete this conversation from your chat home?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(settings.t('Cancel')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete),
            label: Text(settings.t('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(chatServiceProvider).deleteThreadForUser(
            threadId: threadId,
            userId: userId,
          );
      if (context.mounted) {
        messenger?.showSnackBar(
          SnackBar(content: Text(settings.t('Chat deleted.'))),
        );
      }
    } catch (error) {
      if (context.mounted) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text('${settings.t('Could not delete chat')}: $error'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatService = ref.watch(chatServiceProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final settings = ref.watch(appSettingsControllerProvider);
    if (user == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: () => context.go(RouteNames.auth),
          icon: const Icon(Icons.login),
          label: Text(settings.t('Sign in to view chats')),
        ),
      );
    }
    return StreamBuilder(
      stream: chatService.watchThreads(user.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                settings.t(
                  'Could not load chats. Check your Supabase setup and try again.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return LoadingState(label: settings.t('Loading chats...'));
        }
        final threads = snapshot.data!;
        if (threads.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                settings.t(
                    'No chats yet. Open a professional listing and tap Chat to start.'),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: threads.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final thread = threads[index];
            final showingCustomer = user.id == thread.artisanId;
            final title = showingCustomer
                ? (thread.userName ?? 'Customer')
                : (thread.artisanName ?? 'Artisan');
            final photoUrl =
                showingCustomer ? thread.userPhotoUrl : thread.artisanPhotoUrl;
            return Dismissible(
              key: ValueKey(thread.id),
              direction: DismissDirection.horizontal,
              background:
                  const _ChatDeleteBackground(alignment: Alignment.centerLeft),
              secondaryBackground:
                  const _ChatDeleteBackground(alignment: Alignment.centerRight),
              confirmDismiss: (_) async {
                await _deleteThread(context, ref, thread.id, user.id);
                return false;
              },
              child: ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () =>
                          _deleteThread(context, ref, thread.id, user.id),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: settings.t('Delete chat'),
                    ),
                    CircleAvatar(
                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                          ? NetworkImage(photoUrl)
                          : null,
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? const Icon(Icons.person)
                          : null,
                    ),
                  ],
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM d, h:mm a').format(thread.updatedAt),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                subtitle: Text(
                  thread.lastMessage.isEmpty
                      ? settings.t('No messages yet')
                      : thread.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: thread.unreadCount <= 0
                    ? null
                    : Badge.count(
                        count: thread.unreadCount,
                        child: const Icon(Icons.mark_chat_unread_outlined),
                      ),
                onTap: () =>
                    context.push('${RouteNames.chatThread}/${thread.id}'),
              ),
            );
          },
        );
      },
    );
  }
}

class _ChatDeleteBackground extends StatelessWidget {
  const _ChatDeleteBackground({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Icon(
        Icons.delete_outline,
        color: Theme.of(context).colorScheme.onErrorContainer,
      ),
    );
  }
}
