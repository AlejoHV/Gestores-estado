import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import 'task_form_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Do List'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<TaskProvider>().refreshTasks();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          _buildSearchSection(),
          Expanded(child: _buildTaskList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Selector<TaskProvider, TaskFilter>(
      selector: (context, provider) => provider.filter,
      builder: (context, filter, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Todas'),
                        selected: filter == TaskFilter.all,
                        onSelected: (selected) {
                          if (selected)
                            context.read<TaskProvider>().setFilter(
                              TaskFilter.all,
                            );
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Pendientes'),
                        selected: filter == TaskFilter.pending,
                        onSelected: (selected) {
                          if (selected)
                            context.read<TaskProvider>().setFilter(
                              TaskFilter.pending,
                            );
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Completadas'),
                        selected: filter == TaskFilter.completed,
                        onSelected: (selected) {
                          if (selected)
                            context.read<TaskProvider>().setFilter(
                              TaskFilter.completed,
                            );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Selector<TaskProvider, int>(
                selector: (context, provider) => provider.totalCount,
                builder: (context, count, child) {
                  return Text(
                    '$count tareas',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: 'Buscar tareas...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
        onChanged: (value) {
          setState(() {});
        },
      ),
    );
  }

  Widget _buildTaskList() {
    return Selector<
      TaskProvider,
      ({bool isLoading, String? error, List<Task> tasks})
    >(
      selector: (context, provider) => (
        isLoading: provider.isLoading,
        error: provider.error,
        tasks: provider.tasks,
      ),
      builder: (context, data, child) {
        if (data.isLoading && data.tasks.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (data.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${data.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<TaskProvider>().clearError();
                      context.read<TaskProvider>().refreshTasks();
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final filteredTasks = _getFilteredTasks(data.tasks);

        if (filteredTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay tareas',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Agrega una nueva tarea usando el botón +',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await context.read<TaskProvider>().refreshTasks();
          },
          child: ListView.builder(
            itemCount: filteredTasks.length,
            itemBuilder: (context, index) {
              final task = filteredTasks[index];
              return TaskTile(
                task: task,
                onTap: () => _showTaskDetails(task),
                onToggle: () =>
                    context.read<TaskProvider>().toggleTaskCompletion(task),
                onDelete: () => _showDeleteConfirmation(task),
              );
            },
          ),
        );
      },
    );
  }

  List<Task> _getFilteredTasks(List<Task> tasks) {
    final searchTerm = _searchController.text.toLowerCase();
    return tasks.where((task) {
      final matchesSearch = task.title.toLowerCase().contains(searchTerm);
      return matchesSearch;
    }).toList();
  }

  void _showAddTaskDialog() {
    print('DEBUG: _showAddTaskDialog iniciado');

    showDialog(
      context: context,
      builder: (context) => TaskFormDialog(
        onSave: (title, description) async {
          print('DEBUG: onSave callback iniciado con title: $title');
          try {
            await context.read<TaskProvider>().addTask(title, description);
            print('DEBUG: addTask completado en onSave callback');

            if (context.mounted) {
              print('DEBUG: Context mounted en onSave, haciendo Navigator.pop');
              Navigator.of(context).pop();
            }
          } catch (e) {
            print('DEBUG: Error en onSave callback: $e');
            rethrow;
          }
        },
      ),
    );
  }

  void _showTaskDetails(Task task) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => TaskFormScreen(task: task)));
  }

  void _showDeleteConfirmation(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text('¿Estás seguro de eliminar "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              context.read<TaskProvider>().deleteTask(task.id);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class TaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const TaskTile({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Checkbox(
          value: task.completed,
          onChanged: (value) => onToggle(),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.completed ? TextDecoration.lineThrough : null,
            color: task.completed ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description != null && task.description!.isNotEmpty)
              Text(
                task.description!,
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Text(
              'Actualizado: ${_formatDate(task.updatedAt)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Editar'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Eliminar', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onTap();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Ahora';
    }
  }
}
