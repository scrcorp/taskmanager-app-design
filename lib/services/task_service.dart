import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../models/store.dart';

final taskServiceProvider = Provider<TaskService>((ref) {
  return TaskService();
});

/// Pure mock task service — in-memory data persists until refresh
class TaskService {
  Future<List<AdditionalTask>> getMyTasks({String? status}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (status != null) {
      return mockTasks.where((t) => t.status == status).toList();
    }
    return List<AdditionalTask>.from(mockTasks);
  }

  Future<AdditionalTask> getTask(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return mockTasks.firstWhere((t) => t.id == id);
  }

  Future<void> completeTask(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idx = mockTasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final current = mockTasks[idx];
    mockTasks[idx] = AdditionalTask(
      id: current.id,
      store: current.store,
      title: current.title,
      description: current.description,
      priority: current.priority,
      status: 'completed',
      dueDate: current.dueDate,
      createdByName: current.createdByName,
      assignees: current.assignees,
      createdAt: current.createdAt,
    );
  }
}

// ─── Prototype Data ────────────────────────────────────────

final mockTasks = <AdditionalTask>[
  AdditionalTask(
    id: 'task-001',
    store: const Store(id: 'store-001', name: 'Cafe Bloom'),
    title: 'Restock pastry display',
    description: 'Check inventory and restock the pastry display case before lunch rush. Make sure to rotate older items to the front.',
    priority: 'high',
    status: 'pending',
    dueDate: DateTime.now().add(const Duration(hours: 3)),
    createdByName: 'Manager Kim',
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  AdditionalTask(
    id: 'task-002',
    store: const Store(id: 'store-002', name: 'Bistro Garden'),
    title: 'Update menu board',
    description: "Write today's specials on the menu board. Use the new chalk markers from storage.",
    priority: 'normal',
    status: 'in_progress',
    dueDate: DateTime.now().add(const Duration(hours: 5)),
    createdByName: 'Manager Park',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  AdditionalTask(
    id: 'task-003',
    title: 'Submit weekly feedback',
    description: 'Fill out the weekly staff feedback form. Include any suggestions for improving workflow.',
    priority: 'low',
    status: 'completed',
    createdByName: 'HR Team',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  AdditionalTask(
    id: 'task-004',
    store: const Store(id: 'store-001', name: 'Cafe Bloom'),
    title: 'Deep clean ice machine',
    description: 'Follow the cleaning guide posted on the staff bulletin board. Takes approximately 45 minutes.',
    priority: 'high',
    status: 'pending',
    dueDate: DateTime.now().add(const Duration(hours: 6)),
    createdByName: 'Manager Kim',
    createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
  ),
  AdditionalTask(
    id: 'task-005',
    store: const Store(id: 'store-003', name: 'Seoul Station Bakery'),
    title: 'Prepare weekend pre-order list',
    description: 'Compile pre-orders for Saturday and Sunday cakes. Contact customers to confirm delivery times.',
    priority: 'normal',
    status: 'pending',
    dueDate: DateTime.now().add(const Duration(days: 1)),
    createdByName: 'Manager Lee',
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
  ),
  AdditionalTask(
    id: 'task-006',
    title: 'Complete food safety training module',
    description: 'Complete the online food safety training module by end of week. Certificate required.',
    priority: 'low',
    status: 'in_progress',
    dueDate: DateTime.now().add(const Duration(days: 3)),
    createdByName: 'HR Team',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
];
