import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/loading_state.dart';
import '../../routes/route_names.dart';
import '../../services/service_providers.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatService = ref.watch(chatServiceProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: () => context.go(RouteNames.auth),
          icon: const Icon(Icons.login),
          label: const Text('Sign in to view chats'),
        ),
      );
    }
    return StreamBuilder(
      stream: chatService.watchThreads(user.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Could not load chats. Check your Supabase setup and try again.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const LoadingState(label: 'Loading chats...');
        }
        final threads = snapshot.data!;
        if (threads.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No chats yet. Open a professional listing and tap Chat to start.',
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
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                    ? NetworkImage(photoUrl)
                    : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? const Icon(Icons.person)
                    : null,
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
                    ? 'No messages yet'
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
            );
          },
        );
      },
    );
  }
}
