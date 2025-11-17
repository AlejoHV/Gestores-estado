import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import 'memory_database.dart';

class DatabaseService {
  static DatabaseService? _instance;
  static Database? _database;
  static bool _initialized = false;
  static List<Map<String, dynamic>>? _memoryData;

  DatabaseService._internal();

  factory DatabaseService() {
    _instance ??= DatabaseService._internal();
    return _instance!;
  }

  static void initialize() {
    if (!_initialized) {
      // Inicializar databaseFactory para web y desktop
      if (kIsWeb) {
        // Para web, inicializar memoria
        _memoryData = [];
        databaseFactory = databaseFactoryFfi;
      } else {
        // Para desktop/mobile, usar sqflite_common_ffi
        databaseFactory = databaseFactoryFfi;
      }
      _initialized = true;
    }
  }

  Future<Database> get database async {
    if (kIsWeb) {
      // Para web, retornar un mock de base de datos en memoria
      return _getMemoryDatabase();
    }
    _database ??= await _initDatabase();
    return _database!;
  }

  Database _getMemoryDatabase() {
    return MemoryDatabase(_memoryData!);
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      throw Exception('Web usa base de datos en memoria');
    }

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'tasks_database.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabla de tareas
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        completed INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        synced_at TEXT
      );
    ''');

    // Tabla de cola de operaciones para sincronización
    await db.execute('''
      CREATE TABLE queue_operations (
        id TEXT PRIMARY KEY,
        entity TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT,
        created_at INTEGER NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        completed INTEGER NOT NULL DEFAULT 0
      );
    ''');

    // Índices para mejor rendimiento
    await db.execute('CREATE INDEX idx_tasks_updated_at ON tasks(updated_at);');
    await db.execute('CREATE INDEX idx_tasks_deleted ON tasks(deleted);');
    await db.execute(
      'CREATE INDEX idx_queue_operations_entity ON queue_operations(entity, entity_id);',
    );
    await db.execute(
      'CREATE INDEX idx_queue_operations_completed ON queue_operations(completed);',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Manejar futuras migraciones de base de datos
    if (oldVersion < 2) {
      // Ejemplo: agregar nueva columna en versión 2
      // await db.execute('ALTER TABLE tasks ADD COLUMN priority INTEGER DEFAULT 0;');
    }
  }

  // Operaciones para tareas
  Future<int> insertTask(Task task) async {
    final db = await database;
    return await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Convierte un mapa de la base de datos a un objeto Task
  Task _mapToTask(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      completed: (map['completed'] as int) == 1,
      updatedAt: DateTime.parse(map['updated_at'] as String),
      syncedAt: map['synced_at'] == null
          ? null
          : DateTime.parse(map['synced_at'] as String),
    );
  }

  Future<List<Task>> getAllTasks({bool includeDeleted = false}) async {
    final db = await database;

    if (includeDeleted) {
      final List<Map<String, dynamic>> maps = await db.query(
        'tasks',
        orderBy: 'updated_at DESC',
      );
      return List.generate(maps.length, (i) {
        return _mapToTask(maps[i]);
      });
    } else {
      final List<Map<String, dynamic>> maps = await db.query(
        'tasks',
        where: 'deleted = ?',
        whereArgs: [0],
        orderBy: 'updated_at DESC',
      );
      return List.generate(maps.length, (i) {
        return _mapToTask(maps[i]);
      });
    }
  }

  Future<Task?> getTaskById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return _mapToTask(maps.first);
    }
    return null;
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    return await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(String id) async {
    final db = await database;

    // Soft delete: marcar como eliminado en lugar de borrar físicamente
    return await db.update(
      'tasks',
      {'deleted': 1, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> hardDeleteTask(String id) async {
    final db = await database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // Operaciones para cola de sincronización
  Future<int> enqueueOperation({
    required String id,
    required String entity,
    required String entityId,
    required String operation,
    String? payload,
  }) async {
    final db = await database;
    return await db.insert('queue_operations', {
      'id': id,
      'entity': entity,
      'entity_id': entityId,
      'operation': operation,
      'payload': payload,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'attempt_count': 0,
      'completed': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final db = await database;
    return await db.query(
      'queue_operations',
      where: 'completed = 0',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }

  Future<int> markOperationCompleted(String id) async {
    final db = await database;
    return await db.update(
      'queue_operations',
      {'completed': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> incrementOperationAttempts(String id, {String? error}) async {
    final db = await database;

    final updates = {'attempt_count': 'attempt_count + 1'};

    if (error != null) {
      updates['last_error'] = error;
    }

    return await db.update(
      'queue_operations',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Utilidades
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('tasks');
    await db.delete('queue_operations');
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

// Extension para Task para conversión a/desde Map
extension TaskMapExtension on Task {
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'completed': completed ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
      'deleted': 0, // Por defecto no eliminado
    };
  }

  static Task fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      completed: (map['completed'] as int) == 1,
      updatedAt: DateTime.parse(map['updated_at'] as String),
      syncedAt: map['synced_at'] != null
          ? DateTime.parse(map['synced_at'] as String)
          : null,
    );
  }
}
