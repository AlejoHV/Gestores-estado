import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../data/local_task_repository.dart';
import '../data/database_service.dart';
import '../data/database_initializer.dart';
import '../data/sync_service.dart';
import '../data/mock_task_repository.dart';
import '../models/task.dart';

enum TaskFilter { all, pending, completed }

enum SyncStatus { idle, syncing, error }

class TaskProvider with ChangeNotifier {
  final LocalTaskRepository _localRepository;
  final SyncService _syncService;
  final Connectivity _connectivity;

  List<Task> _tasks = [];
  TaskFilter _filter = TaskFilter.all;
  bool _isLoading = false;
  String? _error;
  SyncStatus _syncStatus = SyncStatus.idle;
  String? _syncError;
  bool _isOnline = true;

  TaskProvider()
    : _localRepository = LocalTaskRepository(DatabaseService()),
      _syncService = SyncService(
        localRepository: LocalTaskRepository(DatabaseService()),
        remoteRepository: MockTaskRepository(),
        databaseService: DatabaseService(),
        connectivity: Connectivity(),
      ),
      _connectivity = Connectivity() {
    _initializeDatabase();
    _initializeConnectivity();
    _loadTasks();
  }

  /// Inicializa la base de datos con datos mock si es necesario
  Future<void> _initializeDatabase() async {
    await DatabaseInitializer.initialize();
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
  SyncStatus get syncStatus => _syncStatus;
  String? get syncError => _syncError;
  bool get isOnline => _isOnline;

  int get pendingCount => _tasks.where((task) => !task.completed).length;
  int get completedCount => _tasks.where((task) => task.completed).length;
  int get totalCount => _tasks.length;

  // Actions
  Future<void> _initializeConnectivity() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    _isOnline =
        connectivityResult.isNotEmpty &&
        connectivityResult.first != ConnectivityResult.none;

    _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      final wasOnline = _isOnline;
      _isOnline = result.isNotEmpty && result.first != ConnectivityResult.none;

      // Si recuperamos la conexión, intentar sincronizar
      if (!wasOnline && _isOnline) {
        _syncPendingOperations();
      }

      notifyListeners();
    });
  }

  Future<void> _loadTasks() async {
    _setLoading(true);
    _clearError();

    try {
      // Estrategia Offline-First: cargar datos locales primero
      _tasks = await _localRepository.getTasks();
      notifyListeners();

      // Si hay conexión, sincronizar en segundo plano
      if (_isOnline) {
        await _syncWithServer();
      }
    } catch (e) {
      _setError(_getErrorMessage(e));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _syncWithServer() async {
    if (!_isOnline) return;

    _setSyncStatus(SyncStatus.syncing);
    _clearSyncError();

    try {
      final result = await _syncService.performFullSync();

      if (!result.success) {
        _setSyncError(result.error ?? 'Error desconocido');
        _setSyncStatus(SyncStatus.error);
        return;
      }

      // Recargar tareas locales después de sincronización
      _tasks = await _localRepository.getTasks();
      notifyListeners();

      _setSyncStatus(SyncStatus.idle);
    } catch (e) {
      _setSyncError(_getErrorMessage(e));
      _setSyncStatus(SyncStatus.error);
    }
  }

  Future<void> _syncPendingOperations() async {
    if (!_isOnline) return;

    try {
      await _syncService.performFullSync();

      // Recargar tareas después de sincronizar
      _tasks = await _localRepository.getTasks();
      notifyListeners();
    } catch (e) {
      _setSyncError('Error en sincronización: ${e.toString()}');
    }
  }

  Future<void> refreshTasks() async {
    await _loadTasks();
  }

  Future<void> addTask(String title, String description) async {
    if (title.trim().isEmpty) {
      _setError('El título no puede estar vacío');
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      // Crear tarea localmente primero
      final newTask = await _localRepository.createTask(
        title.trim(),
        description.trim(),
      );

      // Agregar a la lista inmediatamente
      _tasks.add(newTask);
      notifyListeners();

      // Si hay conexión, sincronizar con el servidor
      if (_isOnline) {
        await _syncPendingOperations();
      }
    } catch (e) {
      _setError(_getErrorMessage(e));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> toggleTaskCompletion(Task task) async {
    _setLoading(true);
    _clearError();

    try {
      final updatedTask = task.copyWith(
        completed: !task.completed,
        updatedAt: DateTime.now().toUtc(),
      );

      // Actualizar localmente primero
      await _localRepository.updateTask(updatedTask);

      // Actualizar en la lista
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = updatedTask;
        notifyListeners();
      }

      // Si hay conexión, sincronizar
      if (_isOnline) {
        await _syncPendingOperations();
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
      final updatedTask = task.copyWith(updatedAt: DateTime.now().toUtc());

      // Actualizar localmente primero
      await _localRepository.updateTask(updatedTask);

      // Actualizar en la lista
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = updatedTask;
        notifyListeners();
      }

      // Si hay conexión, sincronizar
      if (_isOnline) {
        await _syncPendingOperations();
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
      // Eliminar localmente primero (soft delete)
      await _localRepository.deleteTask(taskId);

      // Remover de la lista
      _tasks.removeWhere((task) => task.id == taskId);
      notifyListeners();

      // Si hay conexión, sincronizar
      if (_isOnline) {
        await _syncPendingOperations();
      }
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

  void clearSyncError() {
    _clearSyncError();
    notifyListeners();
  }

  Future<void> forceSync() async {
    if (_isOnline) {
      await _syncWithServer();
    } else {
      _setSyncError('No hay conexión a internet');
    }
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

  void _setSyncStatus(SyncStatus status) {
    if (_syncStatus != status) {
      _syncStatus = status;
      notifyListeners();
    }
  }

  void _setSyncError(String error) {
    if (_syncError != error) {
      _syncError = error;
      notifyListeners();
    }
  }

  void _clearSyncError() {
    _syncError = null;
  }

  String _getErrorMessage(dynamic error) {
    // Manejar diferentes tipos de error
    if (error.toString().contains('ApiException')) {
      return error.toString().replaceFirst('ApiException: ', '');
    }
    if (error.toString().contains('Exception:')) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return 'Error inesperado: ${error.toString()}';
  }
}
