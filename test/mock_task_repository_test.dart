import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'dart:convert';
import '../lib/data/mock_task_repository.dart';
import '../lib/models/task.dart';

void main() {
  group('MockTaskRepository Tests', () {
    late MockTaskRepository repository;
    late File originalDbFile;
    late File backupFile;

    setUp(() async {
      repository = MockTaskRepository();
      originalDbFile = File('db.json');
      backupFile = File('db_backup.json');

      // Guardar el archivo original si existe
      if (await originalDbFile.exists()) {
        await originalDbFile.copy('db_backup.json');
        await originalDbFile.delete();
      }

      // Crear archivo de prueba con solo 2 tareas
      final testData = {
        'tasks': [
          {
            'id': 'test-1',
            'title': 'Tarea de prueba 1',
            'description': 'Descripción de prueba 1',
            'completed': false,
            'updatedAt': '2025-01-01T00:00:00.000Z',
          },
          {
            'id': 'test-2',
            'title': 'Tarea de prueba 2',
            'description': 'Descripción de prueba 2',
            'completed': true,
            'updatedAt': '2025-01-02T00:00:00.000Z',
          },
        ],
      };
      await originalDbFile.writeAsString(jsonEncode(testData));

      // Limpiar caché del repositorio
      repository.clearCache();
    });

    tearDown(() async {
      // Eliminar archivo de prueba
      if (await originalDbFile.exists()) {
        await originalDbFile.delete();
      }

      // Restaurar archivo original si existía
      if (await backupFile.exists()) {
        await backupFile.copy('db.json');
        await backupFile.delete();
      }

      // Limpiar caché del repositorio
      repository.clearCache();
    });

    test('debe cargar tareas desde archivo JSON', () async {
      final tasks = await repository.getTasks();

      expect(tasks.length, 2);
      expect(tasks.first.title, 'Tarea de prueba 1');
      expect(tasks.last.title, 'Tarea de prueba 2');
      expect(tasks.first.completed, false);
      expect(tasks.last.completed, true);
    });

    test('debe obtener una tarea específica por ID', () async {
      final task = await repository.getTask('test-1');

      expect(task.id, 'test-1');
      expect(task.title, 'Tarea de prueba 1');
      expect(task.completed, false);
    });

    test('debe lanzar excepción si la tarea no existe', () async {
      expect(
        () => repository.getTask('non-existent-id'),
        throwsA(isA<Exception>()),
      );
    });

    test('debe crear una nueva tarea', () async {
      final newTask = await repository.createTask(
        'Nueva tarea',
        'Descripción nueva',
      );

      expect(newTask.title, 'Nueva tarea');
      expect(newTask.description, 'Descripción nueva');
      expect(newTask.completed, false);
      expect(newTask.id, isNotEmpty);

      // Verificar que se agregó a la lista
      final tasks = await repository.getTasks();
      expect(tasks.length, 3);
      expect(tasks.any((t) => t.id == newTask.id), true);
    });

    test('debe actualizar una tarea existente', () async {
      final tasks = await repository.getTasks();
      final originalTask = tasks.first;

      final updatedTask = originalTask.copyWith(
        title: 'Título actualizado',
        completed: true,
        updatedAt: DateTime.now().toUtc(),
      );

      final result = await repository.updateTask(updatedTask);

      expect(result.title, 'Título actualizado');
      expect(result.completed, true);

      // Verificar que se actualizó en la lista
      final tasksAfter = await repository.getTasks();
      final taskFromList = tasksAfter.firstWhere(
        (t) => t.id == originalTask.id,
      );
      expect(taskFromList.title, 'Título actualizado');
      expect(taskFromList.completed, true);
    });

    test('debe lanzar excepción al actualizar tarea inexistente', () async {
      final nonExistentTask = Task(
        id: 'non-existent',
        title: 'Tarea inexistente',
        description: 'Descripción',
        completed: false,
        updatedAt: DateTime.now().toUtc(),
      );

      expect(
        () => repository.updateTask(nonExistentTask),
        throwsA(isA<Exception>()),
      );
    });

    test('debe eliminar una tarea', () async {
      final tasks = await repository.getTasks();
      final taskToDelete = tasks.first;
      final originalCount = tasks.length;

      await repository.deleteTask(taskToDelete.id);

      final tasksAfter = await repository.getTasks();
      expect(tasksAfter.length, originalCount - 1);
      expect(tasksAfter.any((t) => t.id == taskToDelete.id), false);
    });

    test('debe usar datos fallback cuando no existe el archivo JSON', () async {
      // Eliminar el archivo de prueba
      if (await originalDbFile.exists()) {
        await originalDbFile.delete();
      }

      // Limpiar caché para forzar recarga
      repository.clearCache();

      final tasks = await repository.getTasks();

      // Debe usar los datos fallback hardcoded
      expect(tasks.length, 3);
      expect(tasks.first.title, 'Comprar leche');
      expect(tasks[1].title, 'Estudiar Flutter');
      expect(tasks.last.title, 'Hacer ejercicio');
    });

    test('debe manejar JSON malformado usando datos fallback', () async {
      // Escribir JSON malformado
      await originalDbFile.writeAsString('{"invalid": json}');

      // Limpiar caché para forzar recarga
      repository.clearCache();

      final tasks = await repository.getTasks();

      // Debe usar los datos fallback
      expect(tasks.length, 3);
      expect(tasks.first.title, 'Comprar leche');
    });
  });
}
