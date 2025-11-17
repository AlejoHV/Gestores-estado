import 'dart:convert';
import 'dart:io';
import 'database_service.dart';
import '../models/task.dart';

/// Inicializador de base de datos que carga datos mock desde db.json
class DatabaseInitializer {
  static bool _initialized = false;

  /// Inicializa la base de datos con datos mock si está vacía
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final dbService = DatabaseService();
      final existingTasks = await dbService.getAllTasks();

      // Si no hay tareas, cargar desde db.json
      if (existingTasks.isEmpty) {
        await _loadMockData(dbService);
      }

      _initialized = true;
    } catch (e) {
      // Si hay error, continuar sin datos mock
      print('Error initializing database: $e');
      _initialized = true;
    }
  }

  /// Carga datos mock desde db.json a la base de datos
  static Future<void> _loadMockData(DatabaseService dbService) async {
    try {
      final file = File('db.json');

      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);
        final List<dynamic> tasksJson = data['tasks'];

        for (final taskJson in tasksJson) {
          final task = Task.fromJson(taskJson);
          await dbService.insertTask(task);
        }

        print('Loaded ${tasksJson.length} tasks from db.json');
      } else {
        // Si no existe db.json, cargar datos de ejemplo
        await _loadFallbackData(dbService);
      }
    } catch (e) {
      print('Error loading mock data: $e');
      await _loadFallbackData(dbService);
    }
  }

  /// Carga datos de ejemplo si no hay db.json
  static Future<void> _loadFallbackData(DatabaseService dbService) async {
    final fallbackTasks = [
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

    for (final task in fallbackTasks) {
      await dbService.insertTask(task);
    }

    print('Loaded ${fallbackTasks.length} fallback tasks');
  }
}
