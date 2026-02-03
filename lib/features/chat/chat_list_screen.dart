import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
      return const LoadingState(label: 'Loading chats...');
    }
    return StreamBuilder(
      stream: chatService.watchThreads(user.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LoadingState(label: 'Loading chats...');
        }
        final threads = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: threads.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final thread = threads[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text('Thread ${thread.id}'),
              subtitle: Text(thread.lastMessage),
              onTap: () =>
                  context.go('${RouteNames.chatThread}/${thread.id}'),
            );
          },
        );
      },
    );
  }
}
