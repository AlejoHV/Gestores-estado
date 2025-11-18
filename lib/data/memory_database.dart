import 'package:sqflite/sqflite.dart';

// Mock de Database para web usando memoria
class MemoryDatabase extends Database {
  final List<Map<String, dynamic>> _data;

  MemoryDatabase(this._data);

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (table == 'tasks') {
      var result = _data.where((row) => row['_table'] == 'tasks').toList();

      if (where == 'deleted = 0') {
        result = result.where((row) => row['deleted'] == 0).toList();
      }

      if (where == 'id = ?' && whereArgs != null) {
        result = result.where((row) => row['id'] == whereArgs[0]).toList();
      }

      if (where == 'completed = 0') {
        result = result.where((row) => row['completed'] == 0).toList();
      }

      if (orderBy == 'updated_at DESC') {
        result.sort(
          (a, b) =>
              (b['updated_at'] as String).compareTo(a['updated_at'] as String),
        );
      }

      return result;
    }

    if (table == 'queue_operations') {
      var result = _data
          .where((row) => row['_table'] == 'queue_operations')
          .toList();

      if (where == 'completed = 0') {
        result = result.where((row) => row['completed'] == 0).toList();
      }

      if (orderBy == 'created_at ASC') {
        result.sort(
          (a, b) => (a['created_at'] as int).compareTo(b['created_at'] as int),
        );
      }

      return result;
    }

    return [];
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
    String? nullColumnHack,
  }) async {
    final row = Map<String, dynamic>.from(values);
    row['_table'] = table;

    if (table == 'tasks') {
      if (row['id'] == null) {
        row['id'] = DateTime.now().millisecondsSinceEpoch.toString();
      }
      if (row['completed'] == null) row['completed'] = 0;
      if (row['deleted'] == null) row['deleted'] = 0;
      if (row['updated_at'] == null) {
        row['updated_at'] = DateTime.now().toIso8601String();
      }
    }

    if (table == 'queue_operations') {
      if (row['created_at'] == null) {
        row['created_at'] = DateTime.now().millisecondsSinceEpoch;
      }
      if (row['attempt_count'] == null) row['attempt_count'] = 0;
      if (row['completed'] == null) row['completed'] = 0;
    }

    _data.add(row);
    return 1;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
    String? where,
    List<Object?>? whereArgs,
  }) async {
    int count = 0;

    for (int i = 0; i < _data.length; i++) {
      if (_data[i]['_table'] == table) {
        bool matches = true;

        if (where == 'id = ?' && whereArgs != null) {
          matches = _data[i]['id'] == whereArgs[0];
        }

        if (matches) {
          if (table == 'tasks' && values.containsKey('attempt_count')) {
            // Para incrementOperationAttempts
            _data[i]['attempt_count'] = (_data[i]['attempt_count'] as int) + 1;
            if (values.containsKey('last_error')) {
              _data[i]['last_error'] = values['last_error'];
            }
          } else {
            _data[i].addAll(values);
          }
          count++;
        }
      }
    }

    return count;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    int count = 0;
    _data.removeWhere((row) {
      if (row['_table'] == table) {
        bool matches = true;
        if (where == 'id = ?' && whereArgs != null) {
          matches = row['id'] == whereArgs[0];
        }
        if (matches) count++;
        return matches;
      }
      return false;
    });
    return count;
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    // Mock para CREATE TABLE y otros comandos SQL
    if (sql.contains('CREATE TABLE') || sql.contains('CREATE INDEX')) {
      // No hacer nada, las tablas ya existen en memoria
    }
  }

  @override
  Future<void> close() async {
    // No hacer nada para memoria
  }

  @override
  Batch batch() => MemoryBatch();

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    // For simplicity, just execute the action without real transaction support
    return await action(MemoryTransaction(_data));
  }

  @override
  Future<T> readTransaction<T>(
    Future<T> Function(Transaction txn) action,
  ) async {
    // For simplicity, just execute the action without real transaction support
    return await action(MemoryTransaction(_data));
  }

  @override
  String get path => ':memory:';

  @override
  bool get isOpen => true;

  Future<void> reopen({String? path}) async {}

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    // Basic mock for raw queries
    return [];
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    // Basic mock for raw updates
    return 0;
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    // Basic mock for raw inserts
    return 1;
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    // Basic mock for raw deletes
    return 0;
  }

  Future<void> rawExecute(String sql, [List<Object?>? arguments]) async {
    // Basic mock for raw execute
  }

  Future<List<Object?>> rawQueryRows(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    // Basic mock for raw query rows
    return [];
  }

  @override
  Future<T> devInvokeMethod<T>(String method, [Object? arguments]) async {
    // Mock for development method invocation
    throw UnimplementedError(
      'devInvokeMethod is not implemented in MemoryDatabase',
    );
  }

  @override
  Future<T> devInvokeSqlMethod<T>(
    String method,
    String sql, [
    List<Object?>? arguments,
  ]) async {
    // Mock for development SQL method invocation
    throw UnimplementedError(
      'devInvokeSqlMethod is not implemented in MemoryDatabase',
    );
  }

  Future<void> setLockWarning(int milliseconds) async {
    // Mock for lock warning
  }

  Future<void> enableForeignKeys({bool? enable}) async {
    // Mock for foreign keys
  }

  Future<void> setForeignKeyConstraints({bool? enable}) async {
    // Mock for foreign key constraints
  }

  Future<void> setJournalMode({String? mode}) async {
    // Mock for journal mode
  }

  Future<void> setSynchronousMode({String? mode}) async {
    // Mock for synchronous mode
  }

  Future<void> setTempStore({String? location}) async {
    // Mock for temp store
  }

  Future<void> setWalCheckpoint({
    String? databaseName,
    int? blockSize,
    int? frameCount,
  }) async {
    // Mock for WAL checkpoint
  }

  @override
  Future<QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) async {
    // Mock implementation for query cursor
    throw UnimplementedError(
      'queryCursor is not implemented in MemoryDatabase',
    );
  }

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) async {
    // Mock implementation for raw query cursor
    throw UnimplementedError(
      'rawQueryCursor is not implemented in MemoryDatabase',
    );
  }

  @override
  Database get database => this;
}

class MemoryBatch extends Batch {
  MemoryBatch();

  @override
  void rawInsert(String sql, [List<Object?>? arguments]) {}

  @override
  void rawUpdate(String sql, [List<Object?>? arguments]) {}

  @override
  void rawDelete(String sql, [List<Object?>? arguments]) {}

  @override
  void rawQuery(String sql, [List<Object?>? arguments]) {}

  @override
  void insert(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
    String? nullColumnHack,
  }) {}

  @override
  void update(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
    String? where,
    List<Object?>? whereArgs,
  }) {}

  @override
  void delete(String table, {String? where, List<Object?>? whereArgs}) {}

  @override
  Future<List<Object?>> commit({
    bool? noResult,
    bool? continueOnError,
    bool? exclusive,
  }) async => [];

  @override
  Future<List<Object?>> apply({bool? noResult, bool? continueOnError}) async =>
      [];

  @override
  void execute(String sql, [List<Object?>? arguments]) {}

  @override
  void query(
    String sql, {
    List<String>? columns,
    bool? distinct,
    String? groupBy,
    String? having,
    int? limit,
    int? offset,
    String? orderBy,
    String? where,
    List<Object?>? whereArgs,
  }) {}

  @override
  int get length => 0;
}

class MemoryTransaction extends Transaction {
  final List<Map<String, dynamic>> _data;

  MemoryTransaction(this._data);

  @override
  Future<QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) async {
    // Mock implementation for query cursor
    throw UnimplementedError(
      'queryCursor is not implemented in MemoryTransaction',
    );
  }

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) async {
    // Mock implementation for raw query cursor
    throw UnimplementedError(
      'rawQueryCursor is not implemented in MemoryTransaction',
    );
  }

  @override
  Database get database => MemoryDatabase(_data);

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    // Delegate to the same logic as MemoryDatabase
    final db = MemoryDatabase(_data);
    return await db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
    String? nullColumnHack,
  }) async {
    final db = MemoryDatabase(_data);
    return await db.insert(
      table,
      values,
      conflictAlgorithm: conflictAlgorithm,
      nullColumnHack: nullColumnHack,
    );
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = MemoryDatabase(_data);
    return await db.update(
      table,
      values,
      conflictAlgorithm: conflictAlgorithm,
      where: where,
      whereArgs: whereArgs,
    );
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = MemoryDatabase(_data);
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    final db = MemoryDatabase(_data);
    await db.execute(sql, arguments);
  }

  @override
  Batch batch() => MemoryBatch();

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final db = MemoryDatabase(_data);
    return await db.rawQuery(sql, arguments);
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    final db = MemoryDatabase(_data);
    return await db.rawUpdate(sql, arguments);
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    final db = MemoryDatabase(_data);
    return await db.rawInsert(sql, arguments);
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    final db = MemoryDatabase(_data);
    return await db.rawDelete(sql, arguments);
  }

  Future<void> rollback() async {
    // Mock rollback - in a real implementation this would undo changes
  }

  Future<void> commit() async {
    // Mock commit - in a real implementation this would save changes
  }
}
