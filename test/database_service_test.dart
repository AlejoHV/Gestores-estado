import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/data/database_service.dart';
import '../lib/models/task.dart';

void main() {
  group('DatabaseService Tests', () {
    late DatabaseService databaseService;

    setUpAll(() async {
      // Inicializar FFI para pruebas
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      databaseService = DatabaseService();
      await databaseService.database;
      // Limpiar datos antes de cada prueba
      await databaseService.clearAllData();
    });

    tearDown(() async {
      await databaseService.close();
    });

    test('debe insertar y recuperar una tarea', () async {
      final task = Task(
        id: 'test-1',
        title: 'Tarea de prueba',
        description: 'Descripción de prueba',
        completed: false,
        updatedAt: DateTime.now().toUtc(),
      );

      await databaseService.insertTask(task);

      final tasks = await databaseService.getAllTasks();
      expect(tasks.length, 1);
      expect(tasks.first.title, 'Tarea de prueba');
      expect(tasks.first.completed, false);
    });

    test('debe actualizar una tarea existente', () async {
      final task = Task(
        id: 'test-2',
        title: 'Tarea original',
        description: 'Descripción original',
        completed: false,
        updatedAt: DateTime.now().toUtc(),
      );

      await databaseService.insertTask(task);

      final updatedTask = task.copyWith(
        title: 'Tarea actualizada',
        completed: true,
        updatedAt: DateTime.now().toUtc(),
      );

      await databaseService.updateTask(updatedTask);

      final tasks = await databaseService.getAllTasks();
      expect(tasks.length, 1);
      expect(tasks.first.title, 'Tarea actualizada');
      expect(tasks.first.completed, true);
    });

    test('debe hacer soft delete de una tarea', () async {
      final task = Task(
        id: 'test-3',
        title: 'Tarea para eliminar',
        description: 'Esta tarea será eliminada',
        completed: false,
        updatedAt: DateTime.now().toUtc(),
      );

      await databaseService.insertTask(task);

      // Verificar que existe
      final tasksBefore = await databaseService.getAllTasks();
      expect(tasksBefore.length, 1);

      // Soft delete
      await databaseService.deleteTask(task.id);

      // No debe aparecer en getAllTasks normal
      final tasksAfter = await databaseService.getAllTasks();
      expect(tasksAfter.length, 0);

      // Pero debe aparecer con includeDeleted=true
      final tasksWithDeleted = await databaseService.getAllTasks(
        includeDeleted: true,
      );
      expect(tasksWithDeleted.length, 1);
    });

    test(
      'debe manejar correctamente el campo completed como int/bool',
      () async {
        final task = Task(
          id: 'test-4',
          title: 'Tarea completada',
          description: 'Esta tarea está completada',
          completed: true,
          updatedAt: DateTime.now().toUtc(),
        );

        await databaseService.insertTask(task);

        final tasks = await databaseService.getAllTasks();
        expect(tasks.length, 1);
        expect(tasks.first.completed, true);

        final retrievedTask = await databaseService.getTaskById('test-4');
        expect(retrievedTask?.completed, true);
      },
    );

    test('debe manejar múltiples tareas correctamente', () async {
      final tasks = [
        Task(
          id: 'test-5a',
          title: 'Tarea A',
          description: 'Primera tarea',
          completed: false,
          updatedAt: DateTime.now().toUtc(),
        ),
        Task(
          id: 'test-5b',
          title: 'Tarea B',
          description: 'Segunda tarea',
          completed: true,
          updatedAt: DateTime.now().toUtc(),
        ),
        Task(
          id: 'test-5c',
          title: 'Tarea C',
          description: 'Tercera tarea',
          completed: false,
          updatedAt: DateTime.now().toUtc(),
        ),
      ];

      for (final task in tasks) {
        await databaseService.insertTask(task);
      }

      final allTasks = await databaseService.getAllTasks();
      expect(allTasks.length, 3);

      final completedTasks = allTasks.where((t) => t.completed).toList();
      expect(completedTasks.length, 1);
      expect(completedTasks.first.title, 'Tarea B');
    });
  });
}
