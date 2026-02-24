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
      startDate: current.startDate,
      dueDate: current.dueDate,
      createdByName: current.createdByName,
      assignees: current.assignees,
      labels: current.labels,
      comments: current.comments,
      createdAt: current.createdAt,
      completedAt: DateTime.now(),
      completedByName: 'John Doe',
    );
  }

  Future<void> addComment(String taskId, {required String text, String? imageUrl}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idx = mockTasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;
    final current = mockTasks[idx];
    final newComment = TaskComment(
      id: 'comment-${DateTime.now().microsecondsSinceEpoch}',
      userId: 'user-current',
      userName: 'John Doe',
      text: text,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
    );
    mockTasks[idx] = AdditionalTask(
      id: current.id,
      store: current.store,
      title: current.title,
      description: current.description,
      priority: current.priority,
      status: current.status,
      startDate: current.startDate,
      dueDate: current.dueDate,
      createdByName: current.createdByName,
      assignees: current.assignees,
      labels: current.labels,
      comments: [...current.comments, newComment],
      createdAt: current.createdAt,
      completedAt: current.completedAt,
      completedByName: current.completedByName,
    );
  }

  Future<void> toggleCommentLike(String taskId, String commentId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    // Mock toggle — in real app this would call API
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
    startDate: DateTime.now().subtract(const Duration(hours: 2)),
    dueDate: DateTime.now().add(const Duration(hours: 3)),
    createdByName: 'Manager Kim',
    assignees: [
      TaskAssignee(userId: 'user-current', fullName: 'John Doe'),
      TaskAssignee(userId: 'user-002', fullName: 'Jane Smith'),
    ],
    labels: ['Inventory', 'Urgent'],
    comments: [
      TaskComment(
        id: 'c-001',
        userId: 'user-002',
        userName: 'Jane Smith',
        text: 'I checked the storage room — we have enough croissants but running low on muffins.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
        likes: 2,
      ),
      TaskComment(
        id: 'c-002',
        userId: 'user-current',
        userName: 'John Doe',
        text: 'Got it, I\'ll pick up extra muffins from the supplier.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        likes: 1,
        isLiked: true,
      ),
    ],
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  AdditionalTask(
    id: 'task-002',
    store: const Store(id: 'store-002', name: 'Bistro Garden'),
    title: 'Update menu board',
    description: "Write today's specials on the menu board. Use the new chalk markers from storage.",
    priority: 'normal',
    status: 'in_progress',
    startDate: DateTime.now().subtract(const Duration(hours: 1)),
    dueDate: DateTime.now().add(const Duration(hours: 5)),
    createdByName: 'Manager Park',
    assignees: [
      TaskAssignee(userId: 'user-current', fullName: 'John Doe'),
    ],
    labels: ['Display'],
    comments: [
      TaskComment(
        id: 'c-003',
        userId: 'user-003',
        userName: 'Manager Park',
        text: 'Today\'s specials: Grilled salmon, Caesar salad, Mushroom risotto. Please also add the new dessert — Tiramisu.',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        likes: 3,
      ),
    ],
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  AdditionalTask(
    id: 'task-003',
    title: 'Submit weekly feedback',
    description: 'Fill out the weekly staff feedback form. Include any suggestions for improving workflow.',
    priority: 'low',
    status: 'completed',
    startDate: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
    createdByName: 'HR Team',
    assignees: [
      TaskAssignee(
        userId: 'user-current',
        fullName: 'John Doe',
        isCompleted: true,
        completedAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
    ],
    labels: ['HR', 'Weekly'],
    comments: [],
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    completedAt: DateTime.now().subtract(const Duration(hours: 5)),
    completedByName: 'John Doe',
  ),
  AdditionalTask(
    id: 'task-004',
    store: const Store(id: 'store-001', name: 'Cafe Bloom'),
    title: 'Deep clean ice machine',
    description: 'Follow the cleaning guide posted on the staff bulletin board. Takes approximately 45 minutes.',
    priority: 'high',
    status: 'pending',
    startDate: DateTime.now(),
    dueDate: DateTime.now().add(const Duration(hours: 6)),
    createdByName: 'Manager Kim',
    assignees: [
      TaskAssignee(userId: 'user-current', fullName: 'John Doe'),
    ],
    labels: ['Cleaning', 'Equipment'],
    comments: [
      TaskComment(
        id: 'c-004',
        userId: 'user-004',
        userName: 'Manager Kim',
        text: 'Please make sure to unplug the machine before starting the cleaning process.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
        likes: 1,
      ),
    ],
    createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
  ),
  AdditionalTask(
    id: 'task-005',
    store: const Store(id: 'store-003', name: 'Seoul Station Bakery'),
    title: 'Prepare weekend pre-order list',
    description: 'Compile pre-orders for Saturday and Sunday cakes. Contact customers to confirm delivery times.',
    priority: 'normal',
    status: 'pending',
    startDate: DateTime.now().add(const Duration(hours: 2)),
    dueDate: DateTime.now().add(const Duration(days: 1)),
    createdByName: 'Manager Lee',
    assignees: [
      TaskAssignee(userId: 'user-current', fullName: 'John Doe'),
      TaskAssignee(userId: 'user-005', fullName: 'Amy Lee'),
    ],
    labels: ['Orders'],
    comments: [],
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
  ),
  AdditionalTask(
    id: 'task-006',
    title: 'Complete food safety training module',
    description: 'Complete the online food safety training module by end of week. Certificate required.',
    priority: 'low',
    status: 'in_progress',
    startDate: DateTime.now().subtract(const Duration(days: 1)),
    dueDate: DateTime.now().add(const Duration(days: 3)),
    createdByName: 'HR Team',
    assignees: [
      TaskAssignee(userId: 'user-current', fullName: 'John Doe'),
    ],
    labels: ['Training', 'Required'],
    comments: [
      TaskComment(
        id: 'c-005',
        userId: 'user-006',
        userName: 'HR Team',
        text: 'Reminder: This module is mandatory for all kitchen staff. Deadline is Friday.',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        likes: 0,
      ),
      TaskComment(
        id: 'c-006',
        userId: 'user-current',
        userName: 'John Doe',
        text: 'I\'m halfway through. Will finish by tomorrow.',
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
        likes: 1,
      ),
    ],
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
];
