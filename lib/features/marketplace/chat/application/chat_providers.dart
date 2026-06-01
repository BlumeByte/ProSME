import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/chat_repository.dart';
import '../domain/message_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(Supabase.instance.client);
});

final jobMessagesProvider =
    StreamProvider.family<List<JobMessage>, String>((ref, jobId) {
  return ref.watch(chatRepositoryProvider).watchMessages(jobId);
});
