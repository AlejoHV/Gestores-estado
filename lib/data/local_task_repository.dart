import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import 'database_service.dart';

class LocalTaskRepository {
  final DatabaseService _databaseService;
  final Uuid _uuid = const Uuid();

  LocalTaskRepository(this._databaseService);

  // CRUD Operations
  Future<List<Task>> getTasks() async {
    return await _databaseService.getAllTasks();
  }

  Future<Task?> getTaskById(String id) async {
    return await _databaseService.getTaskById(id);
  }

  Future<Task> createTask(String title, String description) async {
    final now = DateTime.now().toUtc();
    final task = Task(
      id: _uuid.v4(),
      title: title,
      description: description,
      completed: false,
      updatedAt: now,
    );

    // Guardar en base de datos local
    await _databaseService.insertTask(task);

    // Encolar operación para sincronización
    await _databaseService.enqueueOperation(
      id: _uuid.v4(),
      entity: 'task',
      entityId: task.id,
      operation: 'CREATE',
      payload: jsonEncode(task.toJson()),
    );

    return task;
  }

  Future<Task> updateTask(Task task) async {
    final updatedTask = task.copyWith(updatedAt: DateTime.now().toUtc());

    // Actualizar en base de datos local
    await _databaseService.updateTask(updatedTask);

    // Encolar operación para sincronización
    await _databaseService.enqueueOperation(
      id: _uuid.v4(),
      entity: 'task',
      entityId: updatedTask.id,
      operation: 'UPDATE',
      payload: jsonEncode(updatedTask.toJson()),
    );

    return updatedTask;
  }

  Future<void> deleteTask(String id) async {
    // Soft delete en base de datos local
    await _databaseService.deleteTask(id);

    // Encolar operación para sincronización
    await _databaseService.enqueueOperation(
      id: _uuid.v4(),
      entity: 'task',
      entityId: id,
      operation: 'DELETE',
      payload: null,
    );
  }

  // Sincronización
  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    return await _databaseService.getPendingOperations();
  }

  Future<void> markOperationCompleted(String operationId) async {
    await _databaseService.markOperationCompleted(operationId);
  }

  Future<void> incrementOperationAttempts(
    String operationId, {
    String? error,
  }) async {
    await _databaseService.incrementOperationAttempts(
      operationId,
      error: error,
    );
  }

  // Utilidades
  Future<void> clearAllData() async {
    await _databaseService.clearAllData();
  }

  Future<void> syncTaskFromServer(Task serverTask) async {
    final existingTask = await getTaskById(serverTask.id);

    if (existingTask == null) {
      // Nueva tarea del servidor - marcar como sincronizada
      final syncedTask = serverTask.copyWith(syncedAt: DateTime.now().toUtc());
      await _databaseService.insertTask(syncedTask);
    } else {
      // Aplicar estrategia Last-Write-Wins
      if (serverTask.updatedAt.isAfter(existingTask.updatedAt)) {
        final syncedTask = serverTask.copyWith(
          syncedAt: DateTime.now().toUtc(),
        );
        await _databaseService.updateTask(syncedTask);
      }
    }
  }

  Future<void> markTaskAsSynced(String taskId) async {
    final task = await getTaskById(taskId);
    if (task != null) {
      final syncedTask = task.copyWith(
        updatedAt: task.updatedAt, // Mantener el mismo updatedAt
        syncedAt: DateTime.now().toUtc(), // Marcar como sincronizado
      );
      await _databaseService.updateTask(syncedTask);
    }
  }
}
