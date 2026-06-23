import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_models.dart';
import 'db_service.dart';

class ChatSyncService {
  const ChatSyncService._();

  static bool _syncing = false;

  static Future<void> syncPending({
    required SupabaseClient supabase,
    required LocalDbService localDb,
  }) async {
    if (_syncing) return;
    _syncing = true;
    try {
      final actions = await localDb.loadPendingChatActions();
      for (final action in actions) {
        try {
          switch (action.action) {
            case LocalPendingAction.create:
              final message = action.message;
              if (message == null) break;
              final resolved = await _resolveThreadIfOffline(
                supabase: supabase,
                localDb: localDb,
                message: message,
              );
              await _insertMessage(supabase, resolved);
              await _refreshThreadSummary(supabase, resolved.threadId);
              break;
            case LocalPendingAction.update:
              final message = action.message;
              if (message == null) break;
              await supabase
                  .from('messages')
                  .update({'content': message.content}).eq('id', message.id);
              await _refreshThreadSummary(supabase, message.threadId);
              break;
            case LocalPendingAction.delete:
              final threadId = action.threadId;
              final messageId = action.messageId;
              if (threadId == null || messageId == null) break;
              await supabase.from('messages').delete().eq('id', messageId);
              await _refreshThreadSummary(supabase, threadId);
              break;
          }
          await localDb.removePendingChatAction(action.id);
        } catch (error, stackTrace) {
          debugPrint('Chat sync action failed: $error');
          debugPrintStack(stackTrace: stackTrace);
          break;
        }
      }
    } finally {
      _syncing = false;
    }
  }

  static Future<void> _insertMessage(
    SupabaseClient supabase,
    ChatMessage message,
  ) async {
    final payload = message.toJson()..remove('updated_at');
    await supabase.from('messages').upsert(payload, onConflict: 'id');
  }

  static Future<ChatMessage> _resolveThreadIfOffline({
    required SupabaseClient supabase,
    required LocalDbService localDb,
    required ChatMessage message,
  }) async {
    if (!message.threadId.startsWith('offline_')) return message;
    final localThread = await localDb.findThread(message.threadId);
    if (localThread == null) return message;

    final existingRows = await supabase
        .from('threads')
        .select()
        .eq('user_id', localThread.userId)
        .eq('artisan_id', localThread.artisanId)
        .limit(1);
    final remoteThread = existingRows.isNotEmpty
        ? ChatThread.fromJson(
            Map<String, dynamic>.from(existingRows.first as Map),
          )
        : ChatThread.fromJson(
            Map<String, dynamic>.from(
              await supabase
                  .from('threads')
                  .insert({
                    'user_id': localThread.userId,
                    'artisan_id': localThread.artisanId,
                    'last_message': localThread.lastMessage,
                  })
                  .select()
                  .single(),
            ),
          );

    await localDb.replaceThreadId(
      oldThreadId: localThread.id,
      newThread: remoteThread,
    );
    return message.copyWith(threadId: remoteThread.id);
  }

  static Future<void> _refreshThreadSummary(
    SupabaseClient supabase,
    String threadId,
  ) async {
    final rows = await supabase
        .from('messages')
        .select()
        .eq('thread_id', threadId)
        .order('created_at', ascending: false)
        .limit(1);
    final lastMessage = rows.isEmpty
        ? null
        : ChatMessage.fromJson(Map<String, dynamic>.from(rows.first as Map));
    await supabase.from('threads').update({
      'last_message': lastMessage?.threadPreview ?? '',
      'updated_at':
          (lastMessage?.createdAt ?? DateTime.now()).toIso8601String(),
    }).eq('id', threadId);
  }
}
