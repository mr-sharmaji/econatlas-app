import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../datasources/artha_data_source.dart';

/// Local SQLite storage for Artha chat history.
/// Provides instant access to past conversations; syncs with server in background.
class ChatLocalDatabase {
  static Database? _db;
  static const _dbName = 'artha_chat.db';
  static const _dbVersion = 2;

  static Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE chat_sessions (
            id TEXT PRIMARY KEY,
            device_id TEXT NOT NULL,
            title TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            message_count INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE chat_messages (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            thinking_text TEXT,
            stock_cards TEXT,
            mf_cards TEXT,
            feedback INTEGER,
            created_at TEXT NOT NULL,
            FOREIGN KEY (session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_messages_session ON chat_messages(session_id)',
        );
        await db.execute(
          'CREATE INDEX idx_sessions_device ON chat_sessions(device_id)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute(
              'ALTER TABLE chat_messages ADD COLUMN thinking_text TEXT',
            );
          } catch (_) {
            // Ignore duplicate-column upgrades on dev/test builds.
          }
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------

  static Future<void> upsertSession(ChatSession session) async {
    final db = await database;
    await db.insert(
      'chat_sessions',
      {
        'id': session.id,
        'device_id': session.deviceId,
        'title': session.title,
        'created_at': session.createdAt.toIso8601String(),
        'updated_at': session.updatedAt.toIso8601String(),
        'message_count': session.messageCount,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<ChatSession>> getSessions(String deviceId) async {
    final db = await database;
    final rows = await db.query(
      'chat_sessions',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'updated_at DESC',
      limit: 50,
    );
    return rows
        .map((r) => ChatSession(
              id: r['id'] as String,
              deviceId: r['device_id'] as String,
              title: r['title'] as String?,
              createdAt: DateTime.parse(r['created_at'] as String),
              updatedAt: DateTime.parse(r['updated_at'] as String),
              messageCount: (r['message_count'] as int?) ?? 0,
            ))
        .toList();
  }

  static Future<void> deleteSession(String sessionId) async {
    final db = await database;
    await db.delete('chat_messages',
        where: 'session_id = ?', whereArgs: [sessionId]);
    await db.delete('chat_sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  static Future<void> upsertMessage(ChatMessage msg) async {
    final db = await database;
    await db.insert(
      'chat_messages',
      {
        'id': msg.id,
        'session_id': msg.sessionId,
        'role': msg.role,
        'content': msg.content,
        'thinking_text': msg.thinkingText,
        'stock_cards':
            msg.stockCards.isNotEmpty ? jsonEncode(msg.stockCards) : null,
        'mf_cards': msg.mfCards.isNotEmpty ? jsonEncode(msg.mfCards) : null,
        'feedback': msg.feedback,
        'created_at': msg.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<ChatMessage>> getMessages(String sessionId) async {
    final db = await database;
    final rows = await db.query(
      'chat_messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    return rows.map((r) {
      List<Map<String, dynamic>> stockCards = [];
      List<Map<String, dynamic>> mfCards = [];
      if (r['stock_cards'] != null) {
        stockCards = (jsonDecode(r['stock_cards'] as String) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      if (r['mf_cards'] != null) {
        mfCards = (jsonDecode(r['mf_cards'] as String) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return ChatMessage(
        id: r['id'] as String,
        sessionId: r['session_id'] as String,
        role: r['role'] as String,
        content: r['content'] as String,
        thinkingText: r['thinking_text'] as String?,
        stockCards: stockCards,
        mfCards: mfCards,
        feedback: r['feedback'] as int?,
        createdAt: DateTime.parse(r['created_at'] as String),
      );
    }).toList();
  }

  static Future<void> updateFeedback(String messageId, int feedback) async {
    final db = await database;
    await db.update(
      'chat_messages',
      {'feedback': feedback},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  // ---------------------------------------------------------------------------
  // Sync helpers
  // ---------------------------------------------------------------------------

  /// Sync server sessions into local DB (merge, not replace).
  static Future<void> syncFromServer(List<ChatSession> serverSessions) async {
    for (final session in serverSessions) {
      await upsertSession(session);
    }
  }

  /// Save a complete session with messages locally.
  static Future<void> cacheSessionMessages(
    String sessionId,
    List<ChatMessage> messages,
  ) async {
    for (final msg in messages) {
      await upsertMessage(msg);
    }
  }

  /// Enforce 50 session limit — delete oldest beyond limit.
  static Future<void> enforceSessionLimit(String deviceId) async {
    final db = await database;
    final rows = await db.query(
      'chat_sessions',
      columns: ['id'],
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'updated_at DESC',
      offset: 50,
    );
    for (final r in rows) {
      await deleteSession(r['id'] as String);
    }
  }
}
