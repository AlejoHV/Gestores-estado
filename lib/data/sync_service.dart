import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../data/local_task_repository.dart';
import '../data/task_repository.dart';
import '../data/database_service.dart';
import '../models/task.dart';

class SyncService {
  final LocalTaskRepository _localRepository;
  final TaskRepository _remoteRepository;
  final DatabaseService _databaseService;
  final Connectivity _connectivity;

  SyncService({
    required LocalTaskRepository localRepository,
    required TaskRepository remoteRepository,
    required DatabaseService databaseService,
    required Connectivity connectivity,
  }) : _localRepository = localRepository,
       _remoteRepository = remoteRepository,
       _databaseService = databaseService,
       _connectivity = connectivity;

  // Stream para escuchar cambios de conectividad
  Stream<bool> get connectivityStream =>
      _connectivity.onConnectivityChanged.map(
        (results) =>
            results.isNotEmpty && results.first != ConnectivityResult.none,
      );

  // Verificar si hay conexión
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.isNotEmpty && results.first != ConnectivityResult.none;
  }

  // Sincronización completa
  Future<SyncResult> performFullSync() async {
    if (!await isConnected) {
      return SyncResult(
        success: false,
        error: 'No hay conexión a internet',
        operationsProcessed: 0,
      );
    }

    try {
      // 1. Sincronizar desde servidor hacia local
      await _syncFromServerToLocal();

      // 2. Procesar operaciones pendientes
      final operationsProcessed = await _processPendingOperations();

      return SyncResult(
        success: true,
        operationsProcessed: operationsProcessed,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        error: e.toString(),
        operationsProcessed: 0,
      );
    }
  }

  // Sincronizar desde servidor hacia local
  Future<void> _syncFromServerToLocal() async {
    final remoteTasks = await _remoteRepository.getTasks();

    for (final remoteTask in remoteTasks) {
      await _localRepository.syncTaskFromServer(remoteTask);
    }
  }

  // Procesar operaciones pendientes con backoff exponencial
  Future<int> _processPendingOperations() async {
    int processedCount = 0;
    final pendingOperations = await _localRepository.getPendingOperations();

    for (final operation in pendingOperations) {
      final success = await _processOperationWithRetry(operation);
      if (success) {
        processedCount++;
      }
    }

    return processedCount;
  }

  // Procesar operación individual con retry
  Future<bool> _processOperationWithRetry(
    Map<String, dynamic> operation,
  ) async {
    final operationId = operation['id'] as String;
    final entityId = operation['entity_id'] as String;
    final operationType = operation['operation'] as String;
    final payload = operation['payload'] as String?;
    final attemptCount = operation['attempt_count'] as int;

    // Verificar si excedió el máximo de intentos
    if (attemptCount >= _maxRetryAttempts) {
      await _localRepository.incrementOperationAttempts(
        operationId,
        error: 'Máximo de intentos alcanzado',
      );
      return false;
    }

    try {
      switch (operationType) {
        case 'CREATE':
          await _processCreateOperation(payload);
          break;
        case 'UPDATE':
          await _processUpdateOperation(payload);
          break;
        case 'DELETE':
          await _processDeleteOperation(entityId);
          break;
        default:
          throw Exception('Operación desconocida: $operationType');
      }

      // Marcar como completada
      await _localRepository.markOperationCompleted(operationId);
      return true;
    } catch (e) {
      // Incrementar intentos y registrar error
      await _localRepository.incrementOperationAttempts(
        operationId,
        error: e.toString(),
      );

      // Aplicar backoff exponencial antes del próximo intento
      if (attemptCount < _maxRetryAttempts - 1) {
        final delay = _calculateBackoffDelay(attemptCount);
        await Future.delayed(delay);
      }

      return false;
    }
  }

  // Procesar operación CREATE
  Future<void> _processCreateOperation(String? payload) async {
    if (payload == null) throw Exception('Payload nulo para operación CREATE');

    final taskData = _decodeJson(payload);
    final task = Task.fromJson(taskData);
    final createdTask = await _remoteRepository.createTask(
      task.title,
      task.description ?? '',
    );

    // Marcar la tarea local como sincronizada con el ID del servidor
    await _localRepository.markTaskAsSynced(createdTask.id);
  }

  // Procesar operación UPDATE
  Future<void> _processUpdateOperation(String? payload) async {
    if (payload == null) throw Exception('Payload nulo para operación UPDATE');

    final taskData = _decodeJson(payload);
    final task = Task.fromJson(taskData);
    await _remoteRepository.updateTask(task);

    // Marcar la tarea como sincronizada
    await _localRepository.markTaskAsSynced(task.id);
  }

  // Procesar operación DELETE
  Future<void> _processDeleteOperation(String entityId) async {
    await _remoteRepository.deleteTask(entityId);
  }

  // Decodificar JSON de forma segura
  Map<String, dynamic> _decodeJson(String jsonString) {
    try {
      return jsonString as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Error decodificando JSON: $e');
    }
  }

  // Calcular delay con backoff exponencial
  Duration _calculateBackoffDelay(int attemptCount) {
    final baseDelay = Duration(seconds: 1);
    final maxDelay = Duration(minutes: 5);
    final exponentialDelay = baseDelay * pow(2, attemptCount);

    return exponentialDelay > maxDelay ? maxDelay : exponentialDelay;
  }

  // Limpiar operaciones completadas antiguas
  Future<void> cleanupCompletedOperations({Duration? olderThan}) async {
    final cutoffTime = olderThan ?? Duration(days: 7);
    final cutoffTimestamp = DateTime.now()
        .subtract(cutoffTime)
        .millisecondsSinceEpoch;

    final db = await _databaseService.database;
    await db.delete(
      'queue_operations',
      where: 'completed = 1 AND created_at < ?',
      whereArgs: [cutoffTimestamp],
    );
  }

  // Obtener estadísticas de sincronización
  Future<SyncStats> getSyncStats() async {
    final db = await _databaseService.database;

    final pendingResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM queue_operations WHERE completed = 0',
    );
    final pendingCount = pendingResult.first['count'] as int;

    final completedResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM queue_operations WHERE completed = 1',
    );
    final completedCount = completedResult.first['count'] as int;

    final errorResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM queue_operations WHERE last_error IS NOT NULL AND completed = 0',
    );
    final errorCount = errorResult.first['count'] as int;

    return SyncStats(
      pendingOperations: pendingCount,
      completedOperations: completedCount,
      errorOperations: errorCount,
      isConnected: await isConnected,
    );
  }

  // Constantes
  static const int _maxRetryAttempts = 5;
}

// Clases de resultado
class SyncResult {
  final bool success;
  final String? error;
  final int operationsProcessed;

  SyncResult({
    required this.success,
    this.error,
    required this.operationsProcessed,
  });
}

class SyncStats {
  final int pendingOperations;
  final int completedOperations;
  final int errorOperations;
  final bool isConnected;

  SyncStats({
    required this.pendingOperations,
    required this.completedOperations,
    required this.errorOperations,
    required this.isConnected,
  });
}
