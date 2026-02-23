import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/assignment_provider.dart';
import '../../providers/task_provider.dart';

class WorkScreen extends ConsumerStatefulWidget {
  const WorkScreen({super.key});

  @override
  ConsumerState<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends ConsumerState<WorkScreen> {
  @override
  void initState() {
    super.initState();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    Future.microtask(() {
      ref.read(assignmentProvider.notifier).loadAssignments(today);
      ref.read(taskProvider.notifier).loadTasks();
    });
  }

  void _openChecklist(BuildContext context, String assignmentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChecklistBottomSheet(assignmentId: assignmentId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final assignments = ref.watch(assignmentProvider);
    final tasks = ref.watch(taskProvider);

    final tags = <String>{};
    for (final a in assignments.assignments) {
      if (a.store.name.isNotEmpty) tags.add(a.store.name);
      if (a.shift.name.isNotEmpty) tags.add(a.shift.name);
    }

    final totalTasks = tasks.tasks.length;
    final doneTasks = tasks.tasks.where((t) => t.status == 'completed').length;
    final remainingTasks = totalTasks - doneTasks;
    final doneRatio = totalTasks > 0 ? doneTasks / totalTasks : 0.0;

    return RefreshIndicator(
      onRefresh: () async {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await Future.wait([
          ref.read(assignmentProvider.notifier).loadAssignments(today),
          ref.read(taskProvider.notifier).loadTasks(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Profile card ──────────────────────────────────────────────────
          _ProfileCard(user: user, tags: tags.toList()),
          const SizedBox(height: 20),

          // ── Daily Checklist (horizontal scroll) ───────────────────────────
          if (assignments.isLoading)
            const SizedBox(
              height: 72,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (assignments.assignments.isNotEmpty) ...[
            const _SectionLabel(text: 'Daily Checklist'),
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: assignments.assignments.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final a = assignments.assignments[i];
                  final total = a.checklistSnapshot?.totalItems ?? 0;
                  final completed = a.checklistSnapshot?.completedItems ?? 0;
                  final isDone = total > 0 && completed == total;

                  return GestureDetector(
                    onTap: () => _openChecklist(context, a.id),
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDone ? AppColors.successBg : AppColors.accentBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isDone
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: isDone ? AppColors.success : AppColors.accent,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Daily Checklist ($completed/$total)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDone
                                        ? AppColors.success
                                        : AppColors.accent,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  a.store.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDone
                                        ? AppColors.success
                                        : AppColors.accent,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isDone
                                ? Icons.radio_button_checked
                                : Icons.arrow_forward_ios,
                            size: isDone ? 18 : 14,
                            color: isDone ? AppColors.success : AppColors.accent,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── 남은 업무 ────────────────────────────────────────────────────
          if (!tasks.isLoading && totalTasks > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionLabel(text: '남은 업무($remainingTasks/$totalTasks)'),
                Text(
                  '$doneTasks done',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'done',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  'left',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: doneRatio,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // ── 업무목록 ─────────────────────────────────────────────────────
          const _SectionLabel(text: '업무목록'),
          const SizedBox(height: 10),
          if (tasks.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (tasks.tasks.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Text(
                  '업무가 없습니다',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            ...tasks.tasks.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TaskCard(task: t),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── Profile card ─────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final User? user;
  final List<String> tags;

  const _ProfileCard({this.user, required this.tags});

  @override
  Widget build(BuildContext context) {
    final joinDate = user?.createdAt != null
        ? DateFormat('MM/dd/yyyy').format(user!.createdAt!)
        : '-';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'Staff',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.roleName ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '가입일 : $joinDate',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.accentBg,
                child: Text(
                  user?.initials ?? 'ST',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '# $tag',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Task card ────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final AdditionalTask task;

  const _TaskCard({required this.task});

  String get _priorityLabel {
    switch (task.priority) {
      case 'urgent':
        return '긴급';
      case 'high':
        return '보통';
      case 'low':
        return '여유';
      default:
        return task.priorityLabel;
    }
  }

  Color get _priorityColor {
    switch (task.priority) {
      case 'urgent':
        return AppColors.danger;
      case 'high':
        return AppColors.warning;
      default:
        return AppColors.textMuted;
    }
  }

  Color get _priorityBgColor {
    switch (task.priority) {
      case 'urgent':
        return AppColors.dangerBg;
      case 'high':
        return AppColors.warningBg;
      default:
        return AppColors.bg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final duePart = task.dueDate != null
        ? '~ ${DateFormat('MM.dd').format(task.dueDate!)}'
        : null;
    final subtitle = [
      if (task.store?.name != null) task.store!.name,
      if (duePart != null) duePart,
    ].join(' · ');

    return GestureDetector(
      onTap: () => context.push('/tasks/${task.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _priorityBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _priorityLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _priorityColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              size: 13,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

// ─── Checklist bottom sheet ───────────────────────────────────────────────────

class _ChecklistBottomSheet extends ConsumerStatefulWidget {
  final String assignmentId;

  const _ChecklistBottomSheet({required this.assignmentId});

  @override
  ConsumerState<_ChecklistBottomSheet> createState() =>
      _ChecklistBottomSheetState();
}

class _ChecklistBottomSheetState
    extends ConsumerState<_ChecklistBottomSheet> {
  bool _celebrationShown = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(assignmentProvider.notifier)
          .loadAssignment(widget.assignmentId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assignmentProvider);
    final assignment = state.selected;

    if (assignment != null &&
        assignment.checklistSnapshot?.isAllCompleted == true &&
        !_celebrationShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _celebrationShown = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('모든 체크리스트 완료! 수고하셨습니다 🎉'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      });
    }

    final snapshot = assignment?.checklistSnapshot;
    final total = snapshot?.totalItems ?? 0;
    final completed = snapshot?.completedItems ?? 0;
    final progress = total > 0 ? completed / total : 0.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Daily Checklist',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    if (total > 0)
                      Text(
                        '$completed / $total',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                  ],
                ),
              ),

              // Progress bar
              if (total > 0) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation(
                        progress >= 1.0 ? AppColors.success : AppColors.accent,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),

              // Checklist items
              Expanded(
                child: state.isLoading && assignment == null
                    ? const Center(child: CircularProgressIndicator())
                    : snapshot == null || snapshot.items.isEmpty
                        ? const Center(
                            child: Text(
                              '체크리스트 항목이 없습니다',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: EdgeInsets.zero,
                            itemCount: snapshot.items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, color: AppColors.border),
                            itemBuilder: (context, index) {
                              final item = snapshot.items[index];
                              return _ChecklistItemTile(
                                title: item.title,
                                description: item.description,
                                isCompleted: item.isCompleted,
                                completedAtDisplay: item.completedAtDisplay,
                                onToggle: () {
                                  ref
                                      .read(assignmentProvider.notifier)
                                      .toggleChecklistItem(
                                        widget.assignmentId,
                                        item.index,
                                        !item.isCompleted,
                                      );
                                },
                              );
                            },
                          ),
              ),

              // Close button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'close',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Checklist item tile ──────────────────────────────────────────────────────

class _ChecklistItemTile extends StatelessWidget {
  final String title;
  final String? description;
  final bool isCompleted;
  final String? completedAtDisplay;
  final VoidCallback onToggle;

  const _ChecklistItemTile({
    required this.title,
    this.description,
    required this.isCompleted,
    this.completedAtDisplay,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.success : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color:
                        isCompleted ? AppColors.success : AppColors.border,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isCompleted ? AppColors.textMuted : AppColors.text,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  if (description != null && description!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      description!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  if (isCompleted && completedAtDisplay != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      '완료 $completedAtDisplay',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
