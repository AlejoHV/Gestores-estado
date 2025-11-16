import 'package:flutter/foundation.dart';
import '../data/task_repository.dart';
import '../data/http_service.dart';
import '../models/task.dart';

enum TaskFilter { all, pending, completed }

class TaskProvider with ChangeNotifier {
  final TaskRepository _repository;

  List<Task> _tasks = [];
  TaskFilter _filter = TaskFilter.all;
  bool _isLoading = false;
  String? _error;

  TaskProvider() : _repository = TaskRepositoryImpl(HttpService()) {
    _loadTasks();
  }

  // Getters
  List<Task> get tasks {
    switch (_filter) {
      case TaskFilter.pending:
        return _tasks.where((task) => !task.completed).toList();
      case TaskFilter.completed:
        return _tasks.where((task) => task.completed).toList();
      case TaskFilter.all:
        return _tasks;
    }
  }

  TaskFilter get filter => _filter;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get pendingCount => _tasks.where((task) => !task.completed).length;
  int get completedCount => _tasks.where((task) => task.completed).length;
  int get totalCount => _tasks.length;

  // Actions
  Future<void> _loadTasks() async {
    _setLoading(true);
    _clearError();

    try {
      _tasks = await _repository.getTasks();
      notifyListeners();
    } catch (e) {
      _setError(_getErrorMessage(e));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshTasks() async {
    await _loadTasks();
  }

  Future<void> addTask(String title, String description) async {
    print('DEBUG: addTask iniciado con title: $title');

    if (title.trim().isEmpty) {
      _setError('El título no puede estar vacío');
      return;
    }

    print('DEBUG: Validación pasada, configurando loading');
    _setLoading(true);
    _clearError();

    try {
      print('DEBUG: Llamando a repository.createTask');
      final newTask = await _repository.createTask(
        title.trim(),
        description.trim(),
      );
      print('DEBUG: Tarea creada: ${newTask.id}');

      _tasks.add(newTask);
      print('DEBUG: Tarea agregada a la lista');

      // Solo notificar una vez al final
      _setLoading(false);
      notifyListeners();
      print('DEBUG: addTask completado exitosamente');
    } catch (e) {
      print('DEBUG: Error en addTask: $e');
      _setLoading(false);
      _setError(_getErrorMessage(e));
    }
  }

  Future<void> toggleTaskCompletion(Task task) async {
    _setLoading(true);
    _clearError();

    try {
      final updatedTask = task.copyWith(completed: !task.completed);
      final result = await _repository.updateTask(updatedTask);

      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = result;
        notifyListeners();
      }
    } catch (e) {
      _setError(_getErrorMessage(e));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateTask(Task task) async {
    _setLoading(true);
    _clearError();

    try {
      final updatedTask = await _repository.updateTask(task);

      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = updatedTask;
        notifyListeners();
      }
    } catch (e) {
      _setError(_getErrorMessage(e));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteTask(String taskId) async {
    _setLoading(true);
    _clearError();

    try {
      await _repository.deleteTask(taskId);
      _tasks.removeWhere((task) => task.id == taskId);
      notifyListeners();
    } catch (e) {
      _setError(_getErrorMessage(e));
    } finally {
      _setLoading(false);
    }
  }

  void setFilter(TaskFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  // Private methods
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  void _clearError() {
    _error = null;
  }

  String _getErrorMessage(dynamic error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Error inesperado: ${error.toString()}';
  }
}
