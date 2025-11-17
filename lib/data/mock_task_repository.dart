import 'dart:convert';
import 'dart:io';
import '../models/task.dart';
import 'task_repository.dart';

/// Repositorio mock que lee datos del archivo db.json
/// Simula un servidor remoto pero funciona completamente offline
class MockTaskRepository implements TaskRepository {
  List<Task>? _cachedTasks;

  @override
  Future<List<Task>> getTasks() async {
    if (_cachedTasks == null) {
      await _loadMockData();
    }
    return _cachedTasks!;
  }

  @override
  Future<Task> getTask(String id) async {
    await _loadMockDataIfNeeded();
    try {
      return _cachedTasks!.firstWhere((t) => t.id == id);
    } catch (e) {
      throw Exception('Task not found');
    }
  }

  @override
  Future<Task> createTask(String title, String description) async {
    await _loadMockDataIfNeeded();

    // Simular creación de tarea con nuevo ID
    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      completed: false,
      updatedAt: DateTime.now().toUtc(),
    );

    _cachedTasks!.add(newTask);
    return newTask;
  }

  @override
  Future<Task> updateTask(Task task) async {
    await _loadMockDataIfNeeded();

    final index = _cachedTasks!.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _cachedTasks![index] = task;
      return task;
    }

    throw Exception('Task not found');
  }

  @override
  Future<void> deleteTask(String id) async {
    await _loadMockDataIfNeeded();
    _cachedTasks!.removeWhere((t) => t.id == id);
  }

  /// Carga los datos del archivo db.json
  Future<void> _loadMockData() async {
    try {
      // Intentar leer el archivo db.json
      final file = File('db.json');

      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);
        final List<dynamic> tasksJson = data['tasks'];

        _cachedTasks = tasksJson.map((json) => Task.fromJson(json)).toList();
      } else {
        // Si no existe el archivo, usar datos de ejemplo hardcoded
        _cachedTasks = _getFallbackData();
      }
    } catch (e) {
      // Si hay error al leer el archivo, usar datos de ejemplo
      _cachedTasks = _getFallbackData();
    }
  }

  Future<void> _loadMockDataIfNeeded() async {
    if (_cachedTasks == null) {
      await _loadMockData();
    }
  }

  /// Datos de ejemplo si no se puede leer db.json
  List<Task> _getFallbackData() {
    return [
      Task(
        id: '1',
        title: 'Comprar leche',
        description: 'Comprar leche de 1 litro',
        completed: false,
        updatedAt: DateTime.parse('2025-11-15T23:10:12.664Z').toUtc(),
      ),
      Task(
        id: '2',
        title: 'Estudiar Flutter',
        description: 'Estudiar Flutter para crear aplicaciones',
        completed: false,
        updatedAt: DateTime.parse('2025-11-15T21:08:25.254Z').toUtc(),
      ),
      Task(
        id: '3',
        title: 'Hacer ejercicio',
        description: '30 minutos de ejercicio cardiovascular',
        completed: false,
        updatedAt: DateTime.parse('2025-11-14T19:30:00.000Z').toUtc(),
      ),
    ];
  }

  /// Limpia la caché - útil para pruebas
  void clearCache() {
    _cachedTasks = null;
  }
}
