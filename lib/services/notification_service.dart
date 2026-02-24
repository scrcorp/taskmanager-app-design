import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Pure mock notification service — in-memory data persists until refresh
class NotificationService {
  Future<List<AppNotification>> getNotifications({int? page, int? perPage}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List<AppNotification>.from(mockNotifications);
  }

  Future<int> getUnreadCount() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return mockNotifications.where((n) => !n.isRead).length;
  }

  Future<void> markAsRead(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final idx = mockNotifications.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final current = mockNotifications[idx];
    if (current.isRead) return;
    mockNotifications[idx] = AppNotification(
      id: current.id,
      type: current.type,
      message: current.message,
      referenceType: current.referenceType,
      referenceId: current.referenceId,
      isRead: true,
      createdAt: current.createdAt,
    );
  }

  Future<void> markAllAsRead() async {
    await Future.delayed(const Duration(milliseconds: 100));
    for (int i = 0; i < mockNotifications.length; i++) {
      final n = mockNotifications[i];
      if (!n.isRead) {
        mockNotifications[i] = AppNotification(
          id: n.id,
          type: n.type,
          message: n.message,
          referenceType: n.referenceType,
          referenceId: n.referenceId,
          isRead: true,
          createdAt: n.createdAt,
        );
      }
    }
  }
}

// ─── Prototype Data ────────────────────────────────────────

final mockNotifications = <AppNotification>[
  AppNotification(
    id: 'notif-001',
    type: 'work_assigned',
    message: 'You have been assigned to Bistro Garden - Evening shift tomorrow.',
    referenceType: 'work_assignment',
    referenceId: 'asgn-002',
    isRead: false,
    createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
  ),
  AppNotification(
    id: 'notif-002',
    type: 'additional_task',
    message: 'New task: Restock pastry display (High priority)',
    referenceType: 'additional_task',
    referenceId: 'task-001',
    isRead: false,
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  AppNotification(
    id: 'notif-003',
    type: 'announcement',
    message: 'New announcement: New Spring Menu Launch',
    referenceType: 'announcement',
    referenceId: 'ann-001',
    isRead: true,
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
  ),
  AppNotification(
    id: 'notif-004',
    type: 'additional_task',
    message: 'New task: Deep clean ice machine (High priority)',
    referenceType: 'additional_task',
    referenceId: 'task-004',
    isRead: false,
    createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
  ),
  AppNotification(
    id: 'notif-005',
    type: 'work_assigned',
    message: 'You have been assigned to Seoul Station Bakery - Afternoon shift (Feb 26).',
    referenceType: 'work_assignment',
    referenceId: 'asgn-004',
    isRead: false,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  AppNotification(
    id: 'notif-006',
    type: 'announcement',
    message: 'New announcement: System Maintenance Notice',
    referenceType: 'announcement',
    referenceId: 'ann-004',
    isRead: true,
    createdAt: DateTime.now().subtract(const Duration(days: 4)),
  ),
];
