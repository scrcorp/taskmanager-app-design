import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assignment.dart';
import '../models/store.dart';
import '../models/checklist.dart';

final assignmentServiceProvider = Provider<AssignmentService>((ref) {
  return AssignmentService();
});

/// Pure mock assignment service — in-memory data persists until refresh
class AssignmentService {
  Future<List<Assignment>> getMyAssignments({String? workDate, String? status}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    var result = List<Assignment>.from(mockAssignments);
    if (status != null) {
      result = result.where((a) => a.status == status).toList();
    }
    return result;
  }

  Future<Assignment> getAssignment(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return mockAssignments.firstWhere((a) => a.id == id);
  }

  Future<void> toggleChecklistItem(String assignmentId, int itemIndex, bool isCompleted) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _updateChecklistItem(assignmentId, itemIndex, isCompleted: isCompleted);
  }

  Future<void> completeChecklistItemWithVerification(
    String assignmentId,
    int itemIndex, {
    String? photoUrl,
    String? comment,
    String? completedBy,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _updateChecklistItem(
      assignmentId,
      itemIndex,
      isCompleted: true,
      photoUrl: photoUrl,
      comment: comment,
      completedBy: completedBy,
    );
  }

  void _updateChecklistItem(
    String assignmentId,
    int itemIndex, {
    required bool isCompleted,
    String? photoUrl,
    String? comment,
    String? completedBy,
  }) {
    final idx = mockAssignments.indexWhere((a) => a.id == assignmentId);
    if (idx == -1) return;
    final current = mockAssignments[idx];
    if (current.checklistSnapshot == null) return;

    final updatedItems = current.checklistSnapshot!.items.map((item) {
      if (item.index == itemIndex) {
        return item.copyWith(
          isCompleted: isCompleted,
          completedAt: isCompleted ? _formatNow() : null,
          completedTz: isCompleted ? DateTime.now().timeZoneName : null,
          photoUrl: photoUrl,
          comment: comment,
          completedBy: completedBy,
        );
      }
      return item;
    }).toList();

    final updatedSnapshot = ChecklistSnapshot(
      templateId: current.checklistSnapshot!.templateId,
      templateName: current.checklistSnapshot!.templateName,
      snapshotAt: current.checklistSnapshot!.snapshotAt,
      items: updatedItems,
    );

    mockAssignments[idx] = Assignment(
      id: current.id,
      store: current.store,
      shift: current.shift,
      position: current.position,
      status: updatedSnapshot.isAllCompleted ? 'completed' : current.status,
      workDate: current.workDate,
      checklistSnapshot: updatedSnapshot,
      createdAt: current.createdAt,
    );
  }

  static String _formatNow() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mi = now.minute.toString().padLeft(2, '0');
    return '$y-$m-${d}T$hh:$mi';
  }
}

// ─── Prototype Data ────────────────────────────────────────

final mockAssignments = <Assignment>[
  Assignment(
    id: 'asgn-001',
    store: const Store(id: 'store-001', name: 'Cafe Bloom'),
    shift: const ShiftInfo(id: 'shift-001', name: 'Morning (09:00-14:00)'),
    position: const PositionInfo(id: 'pos-001', name: 'Barista'),
    status: 'in_progress',
    workDate: DateTime.now(),
    checklistSnapshot: ChecklistSnapshot(
      templateId: 'tmpl-001',
      templateName: 'Barista Opening Checklist',
      items: const [
        ChecklistItem(index: 0, title: 'Check espresso machine pressure', description: 'Ensure pressure gauge reads 9 bar', verificationType: 'none', isCompleted: true, completedAt: '2026-02-24T09:15', completedTz: '한국 표준시', completedBy: 'park sung min', sortOrder: 0),
        ChecklistItem(index: 1, title: 'Prepare milk station', description: 'Fill milk pitchers, check dairy expiry dates', verificationType: 'comment', isCompleted: true, completedAt: '2026-02-24T09:20', completedTz: '한국 표준시', completedBy: 'park sung min', comment: 'All pitchers filled, expiry OK', sortOrder: 1),
        ChecklistItem(index: 2, title: 'Stock cups and lids', description: 'Ensure at least 50 of each size', verificationType: 'none', isCompleted: false, sortOrder: 2),
        ChecklistItem(index: 3, title: 'Clean counter area', description: 'Wipe all surfaces, sanitize equipment', verificationType: 'photo', isCompleted: false, sortOrder: 3),
        ChecklistItem(index: 4, title: 'Set display pastries', description: 'Arrange fresh pastries in display case', verificationType: 'photo_comment', isCompleted: false, sortOrder: 4),
        ChecklistItem(index: 5, title: 'Turn on signage & music', verificationType: 'none', isCompleted: false, sortOrder: 5),
      ],
    ),
  ),
  Assignment(
    id: 'asgn-002',
    store: const Store(id: 'store-002', name: 'Bistro Garden'),
    shift: const ShiftInfo(id: 'shift-002', name: 'Evening (17:00-22:00)'),
    position: const PositionInfo(id: 'pos-002', name: 'Server'),
    status: 'assigned',
    workDate: DateTime.now().add(const Duration(days: 1)),
    checklistSnapshot: ChecklistSnapshot(
      templateId: 'tmpl-002',
      templateName: 'Server Evening Setup',
      items: const [
        ChecklistItem(index: 0, title: 'Set all tables (cutlery & napkins)', verificationType: 'none', isCompleted: false, sortOrder: 0),
        ChecklistItem(index: 1, title: 'Check reservation list', verificationType: 'comment', isCompleted: false, sortOrder: 1),
        ChecklistItem(index: 2, title: 'Refill condiment stations', verificationType: 'none', isCompleted: false, sortOrder: 2),
        ChecklistItem(index: 3, title: 'Verify POS system is online', verificationType: 'photo', isCompleted: false, sortOrder: 3),
      ],
    ),
  ),
  Assignment(
    id: 'asgn-003',
    store: const Store(id: 'store-001', name: 'Cafe Bloom'),
    shift: const ShiftInfo(id: 'shift-001', name: 'Morning (09:00-14:00)'),
    position: const PositionInfo(id: 'pos-001', name: 'Barista'),
    status: 'completed',
    workDate: DateTime.now().subtract(const Duration(days: 1)),
    checklistSnapshot: ChecklistSnapshot(
      templateId: 'tmpl-001',
      templateName: 'Barista Opening Checklist',
      items: const [
        ChecklistItem(index: 0, title: 'Check espresso machine pressure', verificationType: 'none', isCompleted: true, completedAt: '2026-02-23T09:10', completedTz: '한국 표준시', completedBy: 'park sung min', sortOrder: 0),
        ChecklistItem(index: 1, title: 'Prepare milk station', verificationType: 'none', isCompleted: true, completedAt: '2026-02-23T09:15', completedTz: '한국 표준시', completedBy: 'park sung min', sortOrder: 1),
        ChecklistItem(index: 2, title: 'Stock cups and lids', verificationType: 'none', isCompleted: true, completedAt: '2026-02-23T09:20', completedTz: '한국 표준시', completedBy: 'park sung min', sortOrder: 2),
        ChecklistItem(index: 3, title: 'Clean counter area', verificationType: 'photo', isCompleted: true, completedAt: '2026-02-23T09:25', completedTz: '한국 표준시', completedBy: 'park sung min', sortOrder: 3),
      ],
    ),
  ),
  Assignment(
    id: 'asgn-004',
    store: const Store(id: 'store-003', name: 'Seoul Station Bakery'),
    shift: const ShiftInfo(id: 'shift-003', name: 'Afternoon (14:00-19:00)'),
    position: const PositionInfo(id: 'pos-003', name: 'Baker'),
    status: 'assigned',
    workDate: DateTime.now().add(const Duration(days: 2)),
    checklistSnapshot: ChecklistSnapshot(
      templateId: 'tmpl-003',
      templateName: 'Baker Afternoon Prep',
      items: const [
        ChecklistItem(index: 0, title: 'Preheat all ovens', verificationType: 'none', isCompleted: false, sortOrder: 0),
        ChecklistItem(index: 1, title: 'Check dough proofing status', verificationType: 'photo', isCompleted: false, sortOrder: 1),
        ChecklistItem(index: 2, title: 'Inventory baking supplies', verificationType: 'comment', isCompleted: false, sortOrder: 2),
      ],
    ),
  ),
  Assignment(
    id: 'asgn-005',
    store: const Store(id: 'store-002', name: 'Bistro Garden'),
    shift: const ShiftInfo(id: 'shift-001', name: 'Morning (09:00-14:00)'),
    position: const PositionInfo(id: 'pos-004', name: 'Floor Manager'),
    status: 'completed',
    workDate: DateTime.now().subtract(const Duration(days: 2)),
    checklistSnapshot: ChecklistSnapshot(
      templateId: 'tmpl-004',
      templateName: 'Floor Manager Opening',
      items: const [
        ChecklistItem(index: 0, title: 'Review staff schedule', verificationType: 'none', isCompleted: true, completedAt: '2026-02-22T08:50', completedTz: '한국 표준시', completedBy: 'kim ji yeon', sortOrder: 0),
        ChecklistItem(index: 1, title: 'Check all stations staffed', verificationType: 'none', isCompleted: true, completedAt: '2026-02-22T08:55', completedTz: '한국 표준시', completedBy: 'kim ji yeon', sortOrder: 1),
        ChecklistItem(index: 2, title: 'Inspect dining area cleanliness', verificationType: 'photo', isCompleted: true, completedAt: '2026-02-22T09:00', completedTz: '한국 표준시', completedBy: 'kim ji yeon', sortOrder: 2),
        ChecklistItem(index: 3, title: 'Brief staff on daily specials', verificationType: 'none', isCompleted: true, completedAt: '2026-02-22T09:05', completedTz: '한국 표준시', completedBy: 'kim ji yeon', sortOrder: 3),
        ChecklistItem(index: 4, title: 'Unlock front door at opening time', verificationType: 'none', isCompleted: true, completedAt: '2026-02-22T09:10', completedTz: '한국 표준시', completedBy: 'kim ji yeon', sortOrder: 4),
      ],
    ),
  ),
];
