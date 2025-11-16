import 'package:uuid/uuid.dart';
import '../models/task.dart';
import 'http_service.dart';

//! Interfaz del repositorio de tareas
abstract class TaskRepository {
  Future<List<Task>> getTasks();
  Future<Task> getTask(String id);
  Future<Task> createTask(String title, String description);
  Future<Task> updateTask(Task task);
  Future<void> deleteTask(String id);
}

//! Implementación del repositorio de tareas
class TaskRepositoryImpl implements TaskRepository {
  final HttpService _httpService;
  final Uuid _uuid = const Uuid();

  TaskRepositoryImpl(this._httpService);

  @override
  Future<List<Task>> getTasks() async {
    return await _httpService.getTasks();
  }

  @override
  Future<Task> getTask(String id) async {
    return await _httpService.getTask(id);
  }

  @override
  Future<Task> createTask(String title, String description) async {
    final requestId = _uuid.v4();
    final newTask = Task(
      id: _uuid.v4(),
      title: title,
      completed: false,
      description: description,
      updatedAt: DateTime.now().toUtc(),
    );

    return await _httpService.createTask(newTask, requestId: requestId);
  }

  @override
  Future<Task> updateTask(Task task) async {
    final requestId = _uuid.v4();
    final updatedTask = task.copyWith(updatedAt: DateTime.now().toUtc());

    return await _httpService.updateTask(updatedTask, requestId: requestId);
  }

  @override
  Future<void> deleteTask(String id) async {
    await _httpService.deleteTask(id);
  }
}
