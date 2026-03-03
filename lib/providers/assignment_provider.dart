import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';

class AssignmentState {
  final List<Assignment> assignments;
  final List<Assignment> pastAssignments;
  final Assignment? selected;
  final bool isLoading;
  final bool isPastLoading;
  final String? error;

  const AssignmentState({
    this.assignments = const [],
    this.pastAssignments = const [],
    this.selected,
    this.isLoading = false,
    this.isPastLoading = false,
    this.error,
  });

  AssignmentState copyWith({
    List<Assignment>? assignments,
    List<Assignment>? pastAssignments,
    Assignment? selected,
    bool? isLoading,
    bool? isPastLoading,
    String? error,
  }) {
    return AssignmentState(
      assignments: assignments ?? this.assignments,
      pastAssignments: pastAssignments ?? this.pastAssignments,
      selected: selected ?? this.selected,
      isLoading: isLoading ?? this.isLoading,
      isPastLoading: isPastLoading ?? this.isPastLoading,
      error: error,
    );
  }
}

final assignmentProvider =
    StateNotifierProvider<AssignmentNotifier, AssignmentState>((ref) {
  return AssignmentNotifier(ref.read(assignmentServiceProvider));
});

class AssignmentNotifier extends StateNotifier<AssignmentState> {
  final AssignmentService _service;

  AssignmentNotifier(this._service) : super(const AssignmentState());

  Future<void> loadAssignments(String workDate) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final assignments = await _service.getMyAssignments(workDate: workDate);
      state = state.copyWith(assignments: assignments, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadPastAssignments() async {
    state = state.copyWith(isPastLoading: true, error: null);
    try {
      final past = await _service.getPastAssignments();
      state = state.copyWith(pastAssignments: past, isPastLoading: false);
    } catch (e) {
      state = state.copyWith(isPastLoading: false, error: e.toString());
    }
  }

  Future<void> loadAssignment(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final assignment = await _service.getAssignment(id);
      state = state.copyWith(selected: assignment, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> toggleChecklistItem(
    String assignmentId,
    int itemIndex,
    bool isCompleted,
  ) async {
    await _service.toggleChecklistItem(assignmentId, itemIndex, isCompleted);
    await _reloadAssignment(assignmentId);
  }

  Future<void> completeChecklistItemWithVerification(
    String assignmentId,
    int itemIndex, {
    String? photoUrl,
    String? comment,
    String? completedBy,
  }) async {
    await _service.completeChecklistItemWithVerification(
      assignmentId,
      itemIndex,
      photoUrl: photoUrl,
      comment: comment,
      completedBy: completedBy,
    );
    await _reloadAssignment(assignmentId);
  }

  Future<void> respondToRejection(
    String assignmentId,
    int itemIndex, {
    String? responseComment,
    String? photoUrl,
    String? completedBy,
  }) async {
    await _service.respondToRejection(
      assignmentId,
      itemIndex,
      responseComment: responseComment,
      photoUrl: photoUrl,
      completedBy: completedBy,
    );
    await _reloadAssignment(assignmentId);
    // Also refresh past assignments if they're loaded
    if (state.pastAssignments.isNotEmpty) {
      final past = await _service.getPastAssignments();
      state = state.copyWith(pastAssignments: past);
    }
  }

  Future<void> _reloadAssignment(String assignmentId) async {
    final updated = await _service.getAssignment(assignmentId);
    final updatedList = state.assignments.map((a) {
      return a.id == assignmentId ? updated : a;
    }).toList();
    state = state.copyWith(selected: updated, assignments: updatedList);
  }
}
