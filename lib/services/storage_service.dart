import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';

class ChatSessionMeta {
  final String id;
  final String title;
  final String? modelName;
  final DateTime createdAt;

  ChatSessionMeta({
    required this.id,
    required this.title,
    this.modelName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'modelName': modelName,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ChatSessionMeta.fromJson(Map<String, dynamic> json) =>
      ChatSessionMeta(
        id: json['id'],
        title: json['title'],
        modelName: json['modelName'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}

class StorageService {
  static const _lastModelKey = 'last_model_path';
  static const _chatSessionsKey = 'chat_sessions';
  static const _currentChatKey = 'current_chat_id';

  // ─── Models ───

  static Future<Directory> getModelsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  static Future<List<FileSystemEntity>> getDownloadedModels() async {
    final modelsDir = await getModelsDir();
    final files = modelsDir
        .listSync()
        .where((f) => f.path.endsWith('.gguf'))
        .toList();
    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return files;
  }

  static Future<void> setLastModelPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastModelKey, path);
  }

  static Future<String?> getLastModelPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastModelKey);
  }

  static Future<void> deleteModel(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ─── Chat History ───

  static Future<Directory> _getChatsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final chatsDir = Directory('${appDir.path}/chats');
    if (!await chatsDir.exists()) {
      await chatsDir.create(recursive: true);
    }
    return chatsDir;
  }

  static Future<List<ChatSessionMeta>> getChatSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_chatSessionsKey) ?? [];
    final sessions = <ChatSessionMeta>[];
    for (final s in raw) {
      try {
        sessions.add(ChatSessionMeta.fromJson(jsonDecode(s)));
      } catch (_) {}
    }
    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions;
  }

  static Future<void> _saveChatSessionsMeta(
    List<ChatSessionMeta> sessions,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = sessions.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_chatSessionsKey, raw);
  }

  static Future<String> createNewChat({String? modelName}) async {
    final id = const Uuid().v4();
    final sessions = await getChatSessions();
    sessions.insert(
      0,
      ChatSessionMeta(
        id: id,
        title: 'New Chat',
        modelName: modelName,
        createdAt: DateTime.now(),
      ),
    );
    await _saveChatSessionsMeta(sessions);
    await setCurrentChatId(id);
    return id;
  }

  static Future<void> setCurrentChatId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentChatKey, id);
  }

  static Future<String?> getCurrentChatId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentChatKey);
  }

  static Future<void> saveMessages(
    String chatId,
    List<types.Message> messages,
  ) async {
    final chatsDir = await _getChatsDir();
    final file = File('${chatsDir.path}/$chatId.json');
    final data = messages
        .map((m) {
          if (m is types.TextMessage) {
            return {
              'type': 'text',
              'id': m.id,
              'authorId': m.author.id,
              'authorName': m.author.firstName,
              'text': m.text,
              'createdAt': m.createdAt,
            };
          }
          return null;
        })
        .where((m) => m != null)
        .toList();
    await file.writeAsString(jsonEncode(data));

    // Update title from first user message
    if (messages.isNotEmpty) {
      final sessions = await getChatSessions();
      final idx = sessions.indexWhere((s) => s.id == chatId);
      if (idx != -1) {
        final firstUserMsg = messages.reversed.firstWhere(
          (m) => m is types.TextMessage && m.author.id != 'ai-id',
          orElse: () => messages.last,
        );
        if (firstUserMsg is types.TextMessage) {
          final title = firstUserMsg.text.length > 40
              ? '${firstUserMsg.text.substring(0, 40)}...'
              : firstUserMsg.text;
          sessions[idx] = ChatSessionMeta(
            id: sessions[idx].id,
            title: title,
            modelName: sessions[idx].modelName,
            createdAt: sessions[idx].createdAt,
          );
          await _saveChatSessionsMeta(sessions);
        }
      }
    }
  }

  static Future<List<types.Message>> loadMessages(String chatId) async {
    final chatsDir = await _getChatsDir();
    final file = File('${chatsDir.path}/$chatId.json');
    if (!await file.exists()) return [];

    final data = jsonDecode(await file.readAsString()) as List;
    return data.map<types.Message>((m) {
      return types.TextMessage(
        id: m['id'],
        author: types.User(id: m['authorId'], firstName: m['authorName']),
        text: m['text'] ?? '',
        createdAt: m['createdAt'],
      );
    }).toList();
  }

  static Future<void> deleteChat(String chatId) async {
    final sessions = await getChatSessions();
    sessions.removeWhere((s) => s.id == chatId);
    await _saveChatSessionsMeta(sessions);

    final chatsDir = await _getChatsDir();
    final file = File('${chatsDir.path}/$chatId.json');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
