import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_models.dart';
import '../models/listing.dart';

enum LocalPendingAction { create, update, delete }

class LocalPendingChatAction {
  const LocalPendingChatAction({
    required this.id,
    required this.action,
    required this.createdAt,
    this.message,
    this.threadId,
    this.messageId,
  });

  final String id;
  final LocalPendingAction action;
  final DateTime createdAt;
  final ChatMessage? message;
  final String? threadId;
  final String? messageId;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action.name,
      'created_at': createdAt.toIso8601String(),
      if (message != null) 'message': message!.toJson(),
      if (threadId != null) 'thread_id': threadId,
      if (messageId != null) 'message_id': messageId,
    };
  }

  factory LocalPendingChatAction.fromJson(Map<String, dynamic> json) {
    return LocalPendingChatAction(
      id: (json['id'] ?? '').toString(),
      action: LocalPendingAction.values.firstWhere(
        (action) => action.name == (json['action'] ?? '').toString(),
        orElse: () => LocalPendingAction.create,
      ),
      createdAt: DateTime.tryParse(
            (json['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
      message: json['message'] is Map
          ? ChatMessage.fromJson(Map<String, dynamic>.from(json['message']))
          : null,
      threadId: (json['thread_id'] as String?)?.toString(),
      messageId: (json['message_id'] as String?)?.toString(),
    );
  }
}

class LocalDbService {
  LocalDbService._();

  static final LocalDbService instance = LocalDbService._();

  static const _listingsKey = 'local_cache_listings';
  static const _jobsKey = 'local_cache_jobs';
  static const _pendingJobCreatesKey = 'local_cache_pending_job_creates';
  static const _savedListingIdsPrefix = 'local_cache_saved_listing_ids_';
  static const _pendingSavedListingActionsKey =
      'local_cache_pending_saved_listing_actions';
  static const _threadsKey = 'local_cache_chat_threads';
  static const _messagesKey = 'local_cache_chat_messages';
  static const _hiddenThreadsKey = 'local_cache_hidden_chat_threads';
  static const _hiddenMessagesKey = 'local_cache_hidden_chat_messages';
  static const _pendingChatKey = 'local_cache_pending_chat_actions';

  SharedPreferences? _prefs;
  final _threadControllers = <String, StreamController<List<ChatThread>>>{};
  final _messageControllers = <String, StreamController<List<ChatMessage>>>{};

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> get _store async {
    await init();
    return _prefs!;
  }

  Future<void> cacheListings(List<Listing> listings) async {
    final prefs = await _store;
    await prefs.setString(
      _listingsKey,
      jsonEncode(listings.map((listing) => listing.toJson()).toList()),
    );
  }

  Future<List<Listing>> loadCachedListings() async {
    final prefs = await _store;
    final raw = prefs.getString(_listingsKey);
    if (raw == null || raw.isEmpty) return const [];
    final rows = jsonDecode(raw) as List<dynamic>;
    return rows
        .map((row) => Listing.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  Future<void> cacheJobRows(List<Map<String, dynamic>> jobs) async {
    final prefs = await _store;
    await prefs.setString(_jobsKey, jsonEncode(jobs));
  }

  Future<List<Map<String, dynamic>>> loadCachedJobRows() async {
    final prefs = await _store;
    final raw = prefs.getString(_jobsKey);
    if (raw == null || raw.isEmpty) return const [];
    final rows = jsonDecode(raw) as List<dynamic>;
    return rows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<void> upsertCachedJobRow(Map<String, dynamic> job) async {
    final jobs = await loadCachedJobRows();
    final id = (job['id'] ?? '').toString();
    final next = <Map<String, dynamic>>[];
    var inserted = false;
    for (final row in jobs) {
      if ((row['id'] ?? '').toString() == id) {
        next.add(job);
        inserted = true;
      } else {
        next.add(row);
      }
    }
    if (!inserted) next.insert(0, job);
    await cacheJobRows(_sortJobRows(next));
  }

  Future<void> removeCachedJobRow(String jobId) async {
    final jobs = await loadCachedJobRows();
    await cacheJobRows(
      jobs.where((row) => (row['id'] ?? '').toString() != jobId).toList(),
    );
  }

  Future<void> addPendingJobCreate(Map<String, dynamic> job) async {
    final pending = await loadPendingJobCreates();
    final id = (job['id'] ?? '').toString();
    pending.removeWhere((row) => (row['id'] ?? '').toString() == id);
    pending.add(job);
    await _savePendingJobCreates(pending);
  }

  Future<List<Map<String, dynamic>>> loadPendingJobCreates() async {
    final prefs = await _store;
    final raw = prefs.getString(_pendingJobCreatesKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    final rows = jsonDecode(raw) as List<dynamic>;
    return rows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where((row) => (row['id'] ?? '').toString().isNotEmpty)
        .toList();
  }

  Future<void> removePendingJobCreate(String jobId) async {
    final pending = await loadPendingJobCreates();
    pending.removeWhere((row) => (row['id'] ?? '').toString() == jobId);
    await _savePendingJobCreates(pending);
  }

  Future<void> cacheSavedListingIds(String userId, List<String> ids) async {
    final prefs = await _store;
    await prefs.setStringList(
      '$_savedListingIdsPrefix$userId',
      ids.toSet().toList(growable: false)..sort(),
    );
  }

  Future<List<String>> loadCachedSavedListingIds(String userId) async {
    final prefs = await _store;
    return prefs.getStringList('$_savedListingIdsPrefix$userId') ?? const [];
  }

  Future<void> addCachedSavedListingId(String userId, String listingId) async {
    final ids = (await loadCachedSavedListingIds(userId)).toSet()
      ..add(listingId);
    await cacheSavedListingIds(userId, ids.toList(growable: false));
  }

  Future<void> removeCachedSavedListingId(
    String userId,
    String listingId,
  ) async {
    final ids = (await loadCachedSavedListingIds(userId)).toSet()
      ..remove(listingId);
    await cacheSavedListingIds(userId, ids.toList(growable: false));
  }

  Future<void> addPendingSavedListingAction({
    required String userId,
    required String listingId,
    required String action,
  }) async {
    final pending = await loadPendingSavedListingActions();
    pending.removeWhere(
      (row) =>
          row['user_id'] == userId &&
          row['listing_id'] == listingId &&
          row['action'] != action,
    );
    final id = '$userId:$listingId:$action';
    pending.removeWhere((row) => row['id'] == id);
    pending.add({
      'id': id,
      'user_id': userId,
      'listing_id': listingId,
      'action': action,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _savePendingSavedListingActions(pending);
  }

  Future<List<Map<String, dynamic>>> loadPendingSavedListingActions() async {
    final prefs = await _store;
    final raw = prefs.getString(_pendingSavedListingActionsKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    final rows = jsonDecode(raw) as List<dynamic>;
    return rows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where((row) => (row['id'] ?? '').toString().isNotEmpty)
        .toList();
  }

  Future<void> removePendingSavedListingAction(String id) async {
    final pending = await loadPendingSavedListingActions();
    pending.removeWhere((row) => row['id'] == id);
    await _savePendingSavedListingActions(pending);
  }

  Stream<List<ChatThread>> watchThreads(String userId) async* {
    final controller = _threadControllers.putIfAbsent(
      userId,
      () => StreamController<List<ChatThread>>.broadcast(),
    );
    yield await loadThreads(userId);
    yield* controller.stream;
  }

  Stream<List<ChatMessage>> watchMessages(String threadId) async* {
    final controller = _messageControllers.putIfAbsent(
      threadId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
    yield await loadMessages(threadId);
    yield* controller.stream;
  }

  Future<void> cacheThreadsForUser(
    String userId,
    List<ChatThread> threads,
  ) async {
    final all = await _loadThreadMap();
    all[userId] = threads;
    await _saveThreadMap(all);
    _emitThreads(userId, await loadThreads(userId));
  }

  Future<List<ChatThread>> loadThreads(String userId) async {
    final all = await _loadThreadMap();
    final hidden = await loadHiddenThreadIds(userId);
    final threads = List<ChatThread>.from(all[userId] ?? const []);
    threads.removeWhere((thread) => hidden.contains(thread.id));
    threads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return threads;
  }

  Future<void> upsertThreadForParticipants(ChatThread thread) async {
    await _upsertThreadForUser(thread.userId, thread);
    await _upsertThreadForUser(thread.artisanId, thread);
  }

  Future<ChatThread?> findThread(String threadId) async {
    final all = await _loadThreadMap();
    for (final threads in all.values) {
      for (final thread in threads) {
        if (thread.id == threadId) return thread;
      }
    }
    return null;
  }

  Future<void> replaceThreadId({
    required String oldThreadId,
    required ChatThread newThread,
  }) async {
    final allThreads = await _loadThreadMap();
    for (final entry in allThreads.entries) {
      final index =
          entry.value.indexWhere((thread) => thread.id == oldThreadId);
      if (index == -1) continue;
      entry.value[index] = newThread;
      entry.value.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _emitThreads(entry.key, entry.value);
    }
    await _saveThreadMap(allThreads);

    final allMessages = await _loadMessageMap();
    final oldMessages =
        allMessages.remove(oldThreadId) ?? const <ChatMessage>[];
    if (oldMessages.isNotEmpty) {
      final moved = oldMessages
          .map((message) => message.copyWith(threadId: newThread.id))
          .toList(growable: false);
      final existing = allMessages[newThread.id] ?? const <ChatMessage>[];
      allMessages[newThread.id] = [...existing, ...moved]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _emitMessages(oldThreadId, const []);
      _emitMessages(newThread.id, allMessages[newThread.id]!);
    }
    await _saveMessageMap(allMessages);

    final pending = await loadPendingChatActions();
    final updatedPending = pending.map((action) {
      final message = action.message;
      return LocalPendingChatAction(
        id: action.id,
        action: action.action,
        createdAt: action.createdAt,
        message: message == null || message.threadId != oldThreadId
            ? message
            : message.copyWith(threadId: newThread.id),
        threadId:
            action.threadId == oldThreadId ? newThread.id : action.threadId,
        messageId: action.messageId,
      );
    }).toList(growable: false);
    await _savePendingChatActions(updatedPending);
  }

  Future<void> cacheMessages(String threadId, List<ChatMessage> messages,
      {bool emit = true}) async {
    final all = await _loadMessageMap();
    final sorted = List<ChatMessage>.from(messages)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    all[threadId] = sorted;
    await _saveMessageMap(all);
    if (emit) _emitMessages(threadId, sorted);
  }

  Future<List<ChatMessage>> loadMessages(String threadId) async {
    final all = await _loadMessageMap();
    final messages = List<ChatMessage>.from(all[threadId] ?? const []);
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return messages;
  }

  Future<List<ChatMessage>> loadVisibleMessages(
    String threadId,
    String userId,
  ) async {
    final hidden = await loadHiddenMessageIds(threadId, userId);
    final messages = await loadMessages(threadId);
    return messages
        .where((message) => !hidden.contains(message.id))
        .toList(growable: false);
  }

  Future<void> upsertMessage(ChatMessage message) async {
    final messages = await loadMessages(message.threadId);
    final index = messages.indexWhere((item) => item.id == message.id);
    if (index == -1) {
      messages.add(message);
    } else {
      final existing = messages[index];
      messages[index] =
          message.updatedAt.isAfter(existing.updatedAt) ? message : existing;
    }
    await cacheMessages(message.threadId, messages);
    await _refreshThreadFromMessages(message.threadId);
  }

  Future<void> deleteMessage(String threadId, String messageId) async {
    final messages = await loadMessages(threadId);
    messages.removeWhere((message) => message.id == messageId);
    await cacheMessages(threadId, messages);
    await _refreshThreadFromMessages(threadId);
  }

  Future<void> hideMessagesForUser(
    String threadId,
    String userId,
    Iterable<String> messageIds,
  ) async {
    final all = await _loadHiddenMessageMap();
    final key = '${userId}_$threadId';
    final hidden = {...(all[key] ?? const <String>[]), ...messageIds};
    all[key] = hidden.toList(growable: false);
    await _saveHiddenMessageMap(all);
    final visible = await loadVisibleMessages(threadId, userId);
    _emitMessages(threadId, visible);
  }

  Future<void> emitVisibleMessagesForUser(
    String threadId,
    String userId,
  ) async {
    _emitMessages(threadId, await loadVisibleMessages(threadId, userId));
  }

  Future<void> hideThreadForUser(String threadId, String userId) async {
    final all = await _loadHiddenThreadMap();
    final hidden = {...(all[userId] ?? const <String>[]), threadId};
    all[userId] = hidden.toList(growable: false);
    await _saveHiddenThreadMap(all);

    final messages = await loadMessages(threadId);
    if (messages.isNotEmpty) {
      await hideMessagesForUser(
        threadId,
        userId,
        messages.map((message) => message.id),
      );
    }
    _emitThreads(userId, await loadThreads(userId));
  }

  Future<Set<String>> loadHiddenThreadIds(String userId) async {
    final all = await _loadHiddenThreadMap();
    return (all[userId] ?? const <String>[]).toSet();
  }

  Future<Set<String>> loadHiddenMessageIds(
    String threadId,
    String userId,
  ) async {
    final all = await _loadHiddenMessageMap();
    return (all['${userId}_$threadId'] ?? const <String>[]).toSet();
  }

  Future<void> clearMessages(String threadId) async {
    await cacheMessages(threadId, const []);
    await _refreshThreadFromMessages(threadId);
  }

  Future<void> addPendingChatAction(LocalPendingChatAction action) async {
    final pending = await loadPendingChatActions();
    pending.removeWhere((item) => item.id == action.id);
    pending.add(action);
    await _savePendingChatActions(pending);
  }

  Future<List<LocalPendingChatAction>> loadPendingChatActions() async {
    final prefs = await _store;
    final raw = prefs.getString(_pendingChatKey);
    if (raw == null || raw.isEmpty) return <LocalPendingChatAction>[];
    final rows = jsonDecode(raw) as List<dynamic>;
    final actions = rows
        .map((row) => LocalPendingChatAction.fromJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .where((action) => action.id.isNotEmpty)
        .toList();
    actions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return actions;
  }

  Future<void> removePendingChatAction(String id) async {
    final pending = await loadPendingChatActions();
    pending.removeWhere((action) => action.id == id);
    await _savePendingChatActions(pending);
  }

  Future<Map<String, List<ChatThread>>> _loadThreadMap() async {
    final prefs = await _store;
    final raw = prefs.getString(_threadsKey);
    if (raw == null || raw.isEmpty) return <String, List<ChatThread>>{};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (userId, value) => MapEntry(
        userId,
        (value as List<dynamic>)
            .map((row) => ChatThread.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ))
            .toList(growable: false),
      ),
    );
  }

  Future<void> _saveThreadMap(Map<String, List<ChatThread>> value) async {
    final prefs = await _store;
    await prefs.setString(
      _threadsKey,
      jsonEncode(value.map(
        (userId, threads) => MapEntry(
          userId,
          threads.map((thread) => thread.toJson()).toList(),
        ),
      )),
    );
  }

  Future<Map<String, List<ChatMessage>>> _loadMessageMap() async {
    final prefs = await _store;
    final raw = prefs.getString(_messagesKey);
    if (raw == null || raw.isEmpty) return <String, List<ChatMessage>>{};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (threadId, value) => MapEntry(
        threadId,
        (value as List<dynamic>)
            .map((row) => ChatMessage.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ))
            .toList(growable: false),
      ),
    );
  }

  Future<Map<String, List<String>>> _loadHiddenMessageMap() async {
    final prefs = await _store;
    final raw = prefs.getString(_hiddenMessagesKey);
    if (raw == null || raw.isEmpty) return <String, List<String>>{};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(
        key,
        List<String>.from(value as List<dynamic>),
      ),
    );
  }

  Future<Map<String, List<String>>> _loadHiddenThreadMap() async {
    final prefs = await _store;
    final raw = prefs.getString(_hiddenThreadsKey);
    if (raw == null || raw.isEmpty) return <String, List<String>>{};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(
        key,
        List<String>.from(value as List<dynamic>),
      ),
    );
  }

  Future<void> _saveHiddenThreadMap(Map<String, List<String>> value) async {
    final prefs = await _store;
    await prefs.setString(_hiddenThreadsKey, jsonEncode(value));
  }

  Future<void> _saveHiddenMessageMap(Map<String, List<String>> value) async {
    final prefs = await _store;
    await prefs.setString(_hiddenMessagesKey, jsonEncode(value));
  }

  Future<void> _saveMessageMap(Map<String, List<ChatMessage>> value) async {
    final prefs = await _store;
    await prefs.setString(
      _messagesKey,
      jsonEncode(value.map(
        (threadId, messages) => MapEntry(
          threadId,
          messages.map((message) => message.toJson()).toList(),
        ),
      )),
    );
  }

  Future<void> _savePendingChatActions(
    List<LocalPendingChatAction> actions,
  ) async {
    final prefs = await _store;
    await prefs.setString(
      _pendingChatKey,
      jsonEncode(actions.map((action) => action.toJson()).toList()),
    );
  }

  Future<void> _savePendingJobCreates(List<Map<String, dynamic>> jobs) async {
    final prefs = await _store;
    await prefs.setString(_pendingJobCreatesKey, jsonEncode(jobs));
  }

  Future<void> _savePendingSavedListingActions(
    List<Map<String, dynamic>> actions,
  ) async {
    final prefs = await _store;
    await prefs.setString(_pendingSavedListingActionsKey, jsonEncode(actions));
  }

  List<Map<String, dynamic>> _sortJobRows(List<Map<String, dynamic>> jobs) {
    final next = List<Map<String, dynamic>>.from(jobs);
    next.sort((a, b) {
      final aDate = DateTime.tryParse((a['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse((b['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return next;
  }

  Future<void> _upsertThreadForUser(String userId, ChatThread thread) async {
    if (userId.isEmpty) return;
    final threads = await loadThreads(userId);
    final index = threads.indexWhere((item) => item.id == thread.id);
    if (index == -1) {
      threads.insert(0, thread);
    } else {
      final existing = threads[index];
      threads[index] =
          thread.updatedAt.isAfter(existing.updatedAt) ? thread : existing;
    }
    threads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await cacheThreadsForUser(userId, threads);
  }

  Future<void> _refreshThreadFromMessages(String threadId) async {
    final all = await _loadThreadMap();
    final messages = await loadMessages(threadId);
    final lastMessage = messages.isEmpty ? null : messages.last;
    for (final entry in all.entries) {
      final index = entry.value.indexWhere((thread) => thread.id == threadId);
      if (index == -1) continue;
      final current = entry.value[index];
      entry.value[index] = current.copyWith(
        lastMessage: lastMessage?.threadPreview ?? '',
        updatedAt: lastMessage?.createdAt ?? DateTime.now(),
      );
      entry.value.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _emitThreads(entry.key, entry.value);
    }
    await _saveThreadMap(all);
  }

  void _emitThreads(String userId, List<ChatThread> threads) {
    _threadControllers[userId]?.add(List<ChatThread>.unmodifiable(threads));
  }

  void _emitMessages(String threadId, List<ChatMessage> messages) {
    _messageControllers[threadId]
        ?.add(List<ChatMessage>.unmodifiable(messages));
  }
}
