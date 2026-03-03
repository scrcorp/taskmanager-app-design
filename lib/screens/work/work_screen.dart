import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/assignment.dart';
import '../../models/checklist.dart';
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
  int _tabIndex = 0; // 0 = 오늘, 1 = 과거

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
      builder: (_) => _ChecklistBottomSheet(
        assignmentId: assignmentId,
        isPast: _tabIndex == 1,
      ),
    );
  }

  void _switchTab(int index) {
    setState(() => _tabIndex = index);
    if (index == 1) {
      ref.read(assignmentProvider.notifier).loadPastAssignments();
    }
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

    return RefreshIndicator(
      onRefresh: () async {
        if (_tabIndex == 0) {
          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
          await Future.wait([
            ref.read(assignmentProvider.notifier).loadAssignments(today),
            ref.read(taskProvider.notifier).loadTasks(),
          ]);
        } else {
          await ref.read(assignmentProvider.notifier).loadPastAssignments();
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Profile card ──────────────────────────────────────────────────
          _ProfileCard(user: user, tags: tags.toList()),
          const SizedBox(height: 16),

          // ── Checklist section (grouped card) ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section header
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.accentBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.checklist_rounded,
                        size: 16,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Checklist',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Tab toggle
                _TabToggle(
                  selectedIndex: _tabIndex,
                  onChanged: _switchTab,
                ),
                const SizedBox(height: 12),
                // Checklist content
                if (_tabIndex == 0)
                  _TodayAssignmentList(
                    assignments: assignments,
                    onOpenChecklist: _openChecklist,
                  )
                else
                  _PastContent(
                    assignments: assignments,
                    onOpenChecklist: _openChecklist,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Task section ──────────────────────────────────────────────
          _TodayTaskContent(tasks: tasks),
        ],
      ),
    );
  }
}

// ─── Tab toggle ──────────────────────────────────────────────────────────────

class _TabToggle extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _TabToggle({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildTab('오늘', 0),
          _buildTab('과거', 1),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.text : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Today assignment list ───────────────────────────────────────────────────

class _TodayAssignmentList extends StatelessWidget {
  final AssignmentState assignments;
  final void Function(BuildContext, String) onOpenChecklist;

  const _TodayAssignmentList({
    required this.assignments,
    required this.onOpenChecklist,
  });

  @override
  Widget build(BuildContext context) {
    if (assignments.isLoading) {
      return const SizedBox(
        height: 72,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (assignments.assignments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            '오늘 배정된 체크리스트가 없습니다',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
      );
    }

    return Column(
      children: assignments.assignments.map((a) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _TodayAssignmentCard(
            assignment: a,
            onTap: () => onOpenChecklist(context, a.id),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Today assignment card ───────────────────────────────────────────────────

class _TodayAssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final VoidCallback onTap;

  const _TodayAssignmentCard({
    required this.assignment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final total = a.checklistSnapshot?.totalItems ?? 0;
    final completed = a.checklistSnapshot?.completedItems ?? 0;
    final isDone = total > 0 && completed == total;
    final isWithinShift = a.shift.isWithinShiftHours(DateTime.now());

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDone
                ? AppColors.success.withValues(alpha: 0.4)
                : isWithinShift
                    ? AppColors.accent.withValues(alpha: 0.3)
                    : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            // Date badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDone
                    ? AppColors.successBg
                    : isWithinShift
                        ? AppColors.accentBg
                        : AppColors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  DateFormat('dd').format(a.workDate),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDone
                        ? AppColors.success
                        : isWithinShift
                            ? AppColors.accent
                            : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Store name + shift
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.store.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    a.shift.name,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            // Completion badge
            if (total > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDone ? AppColors.successBg : AppColors.accentBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$completed/$total',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDone ? AppColors.success : AppColors.accent,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Today task content ─────────────────────────────────────────────────────

class _TodayTaskContent extends StatelessWidget {
  final TaskState tasks;

  const _TodayTaskContent({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final totalTasks = tasks.tasks.length;
    final doneTasks = tasks.tasks.where((t) => t.status == 'completed').length;
    final remainingTasks = totalTasks - doneTasks;
    final doneRatio = totalTasks > 0 ? doneTasks / totalTasks : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Task progress
        if (!tasks.isLoading && totalTasks > 0) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionLabel(text: 'Task($remainingTasks/$totalTasks)'),
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

        // ── Task List
        const _SectionLabel(text: 'Task List'),
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
    );
  }
}

// ─── Past content ────────────────────────────────────────────────────────────

class _PastContent extends StatefulWidget {
  final AssignmentState assignments;
  final void Function(BuildContext, String) onOpenChecklist;

  const _PastContent({
    required this.assignments,
    required this.onOpenChecklist,
  });

  @override
  State<_PastContent> createState() => _PastContentState();
}

class _PastContentState extends State<_PastContent> {
  bool _showAll = false;
  bool _unresolvedOnly = false;
  DateTime? _selectedDate;
  int _currentPage = 0;
  static const _pageSize = 5;

  List<Assignment> get _allPast => widget.assignments.pastAssignments;

  /// Unique work dates from past assignments (sorted descending)
  List<DateTime> get _workDates {
    final seen = <String>{};
    final dates = <DateTime>[];
    for (final a in _allPast) {
      final key = DateFormat('yyyy-MM-dd').format(a.workDate);
      if (seen.add(key)) dates.add(a.workDate);
    }
    return dates;
  }

  List<Assignment> get _unresolvedAssignments => _allPast
      .where((a) => (a.checklistSnapshot?.unresolvedRejections ?? []).isNotEmpty)
      .toList();

  bool get _hasActiveFilter => _showAll || _unresolvedOnly || _selectedDate != null;

  List<Assignment> get _filteredAssignments {
    var list = List<Assignment>.from(_allPast);
    if (_showAll) return list;
    if (_unresolvedOnly) {
      list = _unresolvedAssignments;
    }
    if (_selectedDate != null) {
      list = list
          .where((a) =>
              a.workDate.year == _selectedDate!.year &&
              a.workDate.month == _selectedDate!.month &&
              a.workDate.day == _selectedDate!.day)
          .toList();
    }
    return list;
  }

  /// Assignments for the most recent work date
  List<Assignment> get _latestDateAssignments {
    if (_allPast.isEmpty) return [];
    final latestDate = _allPast.first.workDate;
    return _allPast
        .where((a) =>
            a.workDate.year == latestDate.year &&
            a.workDate.month == latestDate.month &&
            a.workDate.day == latestDate.day)
        .toList();
  }

  void _resetFilters() {
    setState(() {
      _showAll = false;
      _unresolvedOnly = false;
      _selectedDate = null;
      _currentPage = 0;
    });
  }

  void _toggleShowAll() {
    setState(() {
      _showAll = !_showAll;
      if (_showAll) {
        _unresolvedOnly = false;
        _selectedDate = null;
      }
      _currentPage = 0;
    });
  }

  void _toggleUnresolvedFilter() {
    setState(() {
      _unresolvedOnly = !_unresolvedOnly;
      if (_unresolvedOnly) _showAll = false;
      _currentPage = 0;
    });
  }

  void _showDateSelector() {
    final dates = _workDates;
    if (dates.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WorkDatePickerSheet(
        workDates: dates,
        selectedDate: _selectedDate,
        onSelect: (date) {
          Navigator.pop(ctx);
          setState(() {
            _selectedDate = date;
            _showAll = false;
            _currentPage = 0;
          });
        },
      ),
    );
  }

  void _clearDate() {
    setState(() {
      _selectedDate = null;
      _currentPage = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.assignments.isPastLoading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_allPast.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            '과거 근무 기록이 없습니다',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Filter row ──
        _buildFilterRow(),
        const SizedBox(height: 12),
        // ── Content ──
        if (!_hasActiveFilter)
          _buildDefaultView()
        else
          _buildFilteredView(),
      ],
    );
  }

  Widget _buildFilterRow() {
    return Row(
      children: [
        // "전체" chip
        _FilterChip(
          label: '전체',
          isActive: _showAll,
          onTap: _toggleShowAll,
        ),
        const SizedBox(width: 6),
        // "미처리" chip
        if (_unresolvedAssignments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _FilterChip(
              label: '미처리 ${_unresolvedAssignments.length}',
              isActive: _unresolvedOnly,
              color: AppColors.warning,
              onTap: _toggleUnresolvedFilter,
            ),
          ),
        // Date picker chip
        if (_selectedDate != null)
          _FilterChip(
            label: DateFormat('MM/dd').format(_selectedDate!),
            isActive: true,
            icon: Icons.close,
            onTap: _clearDate,
          )
        else
          _FilterChip(
            label: '날짜',
            isActive: false,
            icon: Icons.calendar_today,
            onTap: _showDateSelector,
          ),
        const Spacer(),
        // Reset button
        if (_hasActiveFilter)
          GestureDetector(
            onTap: _resetFilters,
            child: const Text(
              '초기화',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDefaultView() {
    final latestAssignments = _latestDateAssignments;
    final latestIds = latestAssignments.map((a) => a.id).toSet();
    // Unresolved items from OTHER dates
    final otherUnresolved =
        _unresolvedAssignments.where((a) => !latestIds.contains(a.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // All assignments from the most recent work date
        ...latestAssignments.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PastAssignmentCard(
                assignment: a,
                onTap: () => widget.onOpenChecklist(context, a.id),
              ),
            )),
        // Unresolved section from other dates
        if (otherUnresolved.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 14, color: AppColors.warning),
                const SizedBox(width: 4),
                Text(
                  '이전 근무 미처리 ${otherUnresolved.length}건',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ...otherUnresolved.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PastAssignmentCard(
                  assignment: a,
                  onTap: () => widget.onOpenChecklist(context, a.id),
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildFilteredView() {
    final filtered = _filteredAssignments;

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            '해당하는 기록이 없습니다',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    final totalPages = (filtered.length / _pageSize).ceil();
    final start = _currentPage * _pageSize;
    final pageItems = filtered.skip(start).take(_pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Items
        ...pageItems.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PastAssignmentCard(
                assignment: a,
                onTap: () => widget.onOpenChecklist(context, a.id),
              ),
            )),
        // Pagination
        if (totalPages > 1) ...[
          const SizedBox(height: 8),
          _buildPagination(totalPages),
        ],
      ],
    );
  }

  Widget _buildPagination(int totalPages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _currentPage > 0
              ? () => setState(() => _currentPage--)
              : null,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _currentPage > 0 ? AppColors.bg : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.chevron_left,
              size: 18,
              color: _currentPage > 0
                  ? AppColors.text
                  : AppColors.border,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${_currentPage + 1} / $totalPages',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _currentPage < totalPages - 1
              ? () => setState(() => _currentPage++)
              : null,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _currentPage < totalPages - 1
                  ? AppColors.bg
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.chevron_right,
              size: 18,
              color: _currentPage < totalPages - 1
                  ? AppColors.text
                  : AppColors.border,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Filter chip ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color? color;
  final IconData? icon;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    this.color,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.1)
              : AppColors.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: isActive ? activeColor : AppColors.textMuted),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? activeColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Work date picker bottom sheet ───────────────────────────────────────────

class _WorkDatePickerSheet extends StatefulWidget {
  final List<DateTime> workDates;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelect;

  const _WorkDatePickerSheet({
    required this.workDates,
    this.selectedDate,
    required this.onSelect,
  });

  @override
  State<_WorkDatePickerSheet> createState() => _WorkDatePickerSheetState();
}

class _WorkDatePickerSheetState extends State<_WorkDatePickerSheet> {
  late DateTime _currentMonth;
  late Set<String> _workDateKeys;

  @override
  void initState() {
    super.initState();
    // Start showing the month of the most recent work date
    _currentMonth = widget.workDates.isNotEmpty
        ? DateTime(widget.workDates.first.year, widget.workDates.first.month)
        : DateTime(DateTime.now().year, DateTime.now().month);
    // Build a set of 'yyyy-MM-dd' keys for O(1) lookup
    _workDateKeys = widget.workDates
        .map((d) => DateFormat('yyyy-MM-dd').format(d))
        .toSet();
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_currentMonth.year, _currentMonth.month + 1);
    if (next.isBefore(DateTime(now.year, now.month + 1))) {
      setState(() => _currentMonth = next);
    }
  }

  bool _isWorkDate(DateTime day) {
    return _workDateKeys.contains(DateFormat('yyyy-MM-dd').format(day));
  }

  bool _isSelected(DateTime day) {
    if (widget.selectedDate == null) return false;
    return day.year == widget.selectedDate!.year &&
        day.month == widget.selectedDate!.month &&
        day.day == widget.selectedDate!.day;
  }

  @override
  Widget build(BuildContext context) {
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1=Mon, 7=Sun

    const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          const Text(
            '근무 날짜 선택',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _prevMonth,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.chevron_left, size: 22, color: AppColors.textSecondary),
                ),
              ),
              Text(
                DateFormat('yyyy년 MM월').format(_currentMonth),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              GestureDetector(
                onTap: _nextMonth,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.chevron_right, size: 22, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Weekday headers
          Row(
            children: weekdayLabels.map((label) {
              return Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Calendar grid
          ..._buildWeeks(year, month, daysInMonth, firstWeekday),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '근무일',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(width: 12),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: AppColors.border),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '근무 없음',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWeeks(int year, int month, int daysInMonth, int firstWeekday) {
    final weeks = <Widget>[];
    // firstWeekday: 1=Mon → offset 0, 7=Sun → offset 6
    final offset = firstWeekday - 1;
    var day = 1;

    while (day <= daysInMonth) {
      final cells = <Widget>[];
      for (var i = 0; i < 7; i++) {
        if ((weeks.isEmpty && i < offset) || day > daysInMonth) {
          cells.add(const Expanded(child: SizedBox(height: 40)));
        } else {
          final thisDay = DateTime(year, month, day);
          final isWork = _isWorkDate(thisDay);
          final isSel = _isSelected(thisDay);

          cells.add(Expanded(
            child: GestureDetector(
              onTap: isWork ? () => widget.onSelect(thisDay) : null,
              child: Container(
                height: 40,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSel
                      ? AppColors.accent
                      : isWork
                          ? AppColors.accentBg
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isWork ? FontWeight.w700 : FontWeight.w400,
                      color: isSel
                          ? AppColors.white
                          : isWork
                              ? AppColors.accent
                              : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ));
          day++;
        }
      }
      weeks.add(Row(children: cells));
    }
    return weeks;
  }
}

// ─── Past assignment card ────────────────────────────────────────────────────

class _PastAssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final VoidCallback onTap;

  const _PastAssignmentCard({
    required this.assignment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final total = a.checklistSnapshot?.totalItems ?? 0;
    final completed = a.checklistSnapshot?.completedItems ?? 0;
    final isDone = total > 0 && completed == total;
    final unresolvedList = a.checklistSnapshot?.unresolvedRejections ?? [];
    final resolvedList =
        a.checklistSnapshot?.items.where((i) => i.isResolved).toList() ?? [];
    final hasUnresolved = unresolvedList.isNotEmpty;
    final hasResolved = resolvedList.isNotEmpty;
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final wd = weekdays[a.workDate.weekday - 1];
    final dateStr = '${DateFormat('MM/dd').format(a.workDate)} ($wd)';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasUnresolved
                ? AppColors.warning.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Date badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hasUnresolved
                        ? AppColors.warningBg
                        : isDone
                            ? AppColors.successBg
                            : AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      DateFormat('dd').format(a.workDate),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: hasUnresolved
                            ? AppColors.warning
                            : isDone
                                ? AppColors.success
                                : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${a.store.name} · ${a.shift.name}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          if (hasUnresolved) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.warningBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '미처리 ${unresolvedList.length}건',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ] else if (hasResolved) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.accentBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '처리 완료 ${resolvedList.length}건',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Completion badge
                if (total > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDone ? AppColors.successBg : AppColors.warningBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$completed/$total',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDone ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ),
              ],
            ),
            // Unresolved rejection feedback (orange)
            if (hasUnresolved) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: unresolvedList.map((item) {
                    return Padding(
                      padding: EdgeInsets.only(
                          top: item == unresolvedList.first ? 0 : 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.feedback_outlined,
                                size: 14, color: AppColors.warning),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text,
                                  ),
                                ),
                                if (item.rejectionComment != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    item.rejectionComment!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 2),
                                Text(
                                  '${item.rejectedBy ?? ''} ${item.rejectedAtDisplay ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            // Resolved feedback (accent/purple - completed)
            if (hasResolved && !hasUnresolved) ...[
              const SizedBox(height: 10),
              ...resolvedList.map((item) {
                return Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(
                      top: item == resolvedList.first ? 0 : 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.check_circle_outline,
                            size: 14, color: AppColors.accent),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            if (item.responseComment != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.responseComment!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.accent,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
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
              GestureDetector(
                onTap: () => context.push('/my'),
                child: Stack(
                  children: [
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
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
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
  final bool isPast;

  const _ChecklistBottomSheet({required this.assignmentId, this.isPast = false});

  @override
  ConsumerState<_ChecklistBottomSheet> createState() =>
      _ChecklistBottomSheetState();
}

class _ChecklistBottomSheetState
    extends ConsumerState<_ChecklistBottomSheet> {
  bool _celebrationShown = false;
  Timer? _autoCloseTimer;

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
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  void _startAutoCloseTimer() {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  void _onItemTap(ChecklistItem item) {
    // Past tab: view-only, open detail sheet
    if (widget.isPast) {
      _showItemDetailSheet(context, item);
      return;
    }

    // Check if within shift hours
    final assignment = ref.read(assignmentProvider).selected;
    if (assignment != null &&
        !assignment.shift.isWithinShiftHours(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아직 근무시간이 아닙니다.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (item.isCompleted && !item.isRejected) return;

    // Rejected items always open response sheet
    if (item.isRejected) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _RejectionResponseSheet(
          assignmentId: widget.assignmentId,
          item: item,
        ),
      );
      return;
    }

    if (item.requiresVerification) {
      // Open verification detail bottom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _VerificationBottomSheet(
          assignmentId: widget.assignmentId,
          item: item,
        ),
      );
    } else {
      // Simple toggle
      ref
          .read(assignmentProvider.notifier)
          .toggleChecklistItem(
            widget.assignmentId,
            item.index,
            !item.isCompleted,
          );
    }
  }

  void _showItemDetailSheet(BuildContext context, ChecklistItem item) {
    if (item.isRejected && !item.isResolved) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _RejectionResponseSheet(
          assignmentId: widget.assignmentId,
          item: item,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemDetailSheet(item: item),
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
          if (!widget.isPast) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('모든 체크리스트 완료! 수고하셨습니다 🎉'),
                duration: Duration(seconds: 2),
              ),
            );
            _startAutoCloseTimer();
          }
        }
      });
    }

    final snapshot = assignment?.checklistSnapshot;
    final total = snapshot?.totalItems ?? 0;
    final completed = snapshot?.completedItems ?? 0;
    final progress = total > 0 ? completed / total : 0.0;
    final isAllDone = total > 0 && completed == total;

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
                      'Checklist',
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
                                item: item,
                                onTap: () => _onItemTap(item),
                                onTapDetail: () => _showItemDetailSheet(context, item),
                              );
                            },
                          ),
              ),

              // Close / Done button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: isAllDone
                        ? ElevatedButton(
                            onPressed: () {
                              _autoCloseTimer?.cancel();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'DONE',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          )
                        : OutlinedButton(
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
  final ChecklistItem item;
  final VoidCallback onTap;
  final VoidCallback? onTapDetail;

  const _ChecklistItemTile({
    required this.item,
    required this.onTap,
    this.onTapDetail,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onTapDetail,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: item.isRejected
                      ? AppColors.warningBg
                      : item.isCompleted
                          ? AppColors.success
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: item.isRejected
                        ? AppColors.warning
                        : item.isCompleted
                            ? AppColors.success
                            : AppColors.border,
                    width: 2,
                  ),
                ),
                child: item.isRejected
                    ? const Icon(Icons.refresh, size: 13, color: AppColors.warning)
                    : item.isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: item.isCompleted && !item.isRejected
                                ? AppColors.textMuted
                                : AppColors.text,
                            decoration: item.isCompleted && !item.isRejected
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                      if (item.isResolved)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '처리 완료',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        )
                      else if (item.isRejected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warningBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '재요청',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (item.description != null && item.description!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.description!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  if (item.isCompleted && !item.isRejected && item.completedAtDisplay != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.isResolved
                          ? '재수행 완료 ${item.respondedAtDisplay ?? ''}${item.respondedBy != null ? ' · ${item.respondedBy}' : ''}'
                          : '완료 ${item.completedAtDisplay}${item.completedBy != null ? ' · ${item.completedBy}' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: item.isResolved ? AppColors.accent : AppColors.success,
                      ),
                    ),
                  ],
                  // Photo thumbnail indicator
                  if (item.allPhotoUrls.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            item.allPhotoUrls.first,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.photo_outlined,
                                  size: 20, color: AppColors.textMuted),
                            ),
                          ),
                        ),
                        if (item.allPhotoUrls.length > 1) ...[
                          const SizedBox(width: 4),
                          Text(
                            '+${item.allPhotoUrls.length - 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  // Resolved: show response comment inline
                  if (item.isResolved && item.responseComment != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.rejectionComment != null)
                            Text(
                              '피드백: ${item.rejectionComment}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (item.rejectionComment != null) const SizedBox(height: 3),
                          Text(
                            '응답: ${item.responseComment}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.accent,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Inline rejection feedback
                  if (item.isRejected && item.rejectionComment != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onTap,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline,
                                    size: 12, color: AppColors.warning),
                                const SizedBox(width: 4),
                                if (item.rejectedBy != null)
                                  Text(
                                    item.rejectedBy!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                const Spacer(),
                                if (item.rejectedAtDisplay != null)
                                  Text(
                                    item.rejectedAtDisplay!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.warning.withValues(alpha: 0.7),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.rejectionComment!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.text,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '재보고하기',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: AppColors.accent,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Verification type icons
            if (item.requiresVerification && !item.isCompleted && !item.isRejected) ...[
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.requiresPhoto)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 16,
                        color: AppColors.accent.withValues(alpha: 0.7),
                      ),
                    ),
                  if (item.requiresComment)
                    Icon(
                      Icons.edit_note,
                      size: 18,
                      color: AppColors.accent.withValues(alpha: 0.7),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Verification bottom sheet ──────────────────────────────────────────────

class _VerificationBottomSheet extends ConsumerStatefulWidget {
  final String assignmentId;
  final ChecklistItem item;

  const _VerificationBottomSheet({
    required this.assignmentId,
    required this.item,
  });

  @override
  ConsumerState<_VerificationBottomSheet> createState() =>
      _VerificationBottomSheetState();
}

class _VerificationBottomSheetState
    extends ConsumerState<_VerificationBottomSheet> {
  final _commentController = TextEditingController();
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_isSubmitting) return false;
    if (widget.item.requiresPhoto && _pickedImageBytes == null) return false;
    if (widget.item.requiresComment && _commentController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageName = picked.name;
      });
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageName = picked.name;
      });
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);

    final user = ref.read(authProvider).user;

    await ref.read(assignmentProvider.notifier).completeChecklistItemWithVerification(
      widget.assignmentId,
      widget.item.index,
      photoUrl: _pickedImageName,
      comment: _commentController.text.trim().isNotEmpty
          ? _commentController.text.trim()
          : null,
      completedBy: user?.fullName,
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Checklist',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),

              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Task info
                    Text(
                      widget.item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    if (widget.item.description != null &&
                        widget.item.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.item.description!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Photo verification section
                    if (widget.item.requiresPhoto) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text(
                                  '인증',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.camera_alt_outlined,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '작업 완료 인증을 해주세요.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Image preview or placeholder
                            if (_pickedImageBytes != null)
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      _pickedImageBytes!,
                                      width: double.infinity,
                                      height: 200,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () => setState(() {
                                        _pickedImageBytes = null;
                                        _pickedImageName = null;
                                      }),
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  width: double.infinity,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.border,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 40,
                                        color: AppColors.textMuted,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        '사진을 추가해주세요',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            const SizedBox(height: 12),

                            // Camera / Gallery buttons
                            if (_pickedImageBytes == null)
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _takePhoto,
                                      icon: const Icon(Icons.camera_alt, size: 16),
                                      label: const Text('촬영'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.accent,
                                        side: const BorderSide(color: AppColors.accent),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _pickImage,
                                      icon: const Icon(Icons.photo_library, size: 16),
                                      label: const Text('갤러리'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.textSecondary,
                                        side: const BorderSide(color: AppColors.border),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Comment section
                    if (widget.item.requiresComment) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text(
                                  '코멘트',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.edit_note,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '작업 내용을 기록해주세요.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _commentController,
                              maxLines: 4,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.text,
                              ),
                              decoration: InputDecoration(
                                hintText: '코멘트를 입력하세요...',
                                hintStyle: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textMuted,
                                ),
                                filled: true,
                                fillColor: AppColors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.accent),
                                ),
                                contentPadding: const EdgeInsets.all(14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),

              // DONE + Close buttons
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _canSubmit ? _submit : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.border,
                            disabledForegroundColor: AppColors.textMuted,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'DONE',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ],
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

// ─── Rejection response bottom sheet ──────────────────────────────────────────

class _RejectionResponseSheet extends ConsumerStatefulWidget {
  final String assignmentId;
  final ChecklistItem item;

  const _RejectionResponseSheet({
    required this.assignmentId,
    required this.item,
  });

  @override
  ConsumerState<_RejectionResponseSheet> createState() =>
      _RejectionResponseSheetState();
}

class _RejectionResponseSheetState
    extends ConsumerState<_RejectionResponseSheet> {
  final _commentController = TextEditingController();
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  bool _isSubmitting = false;
  bool _isHistoryExpanded = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_isSubmitting) return false;
    if (_commentController.text.trim().isEmpty) return false;
    if (widget.item.requiresPhoto && _pickedImageBytes == null) return false;
    return true;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageName = picked.name;
      });
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageName = picked.name;
      });
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);

    final user = ref.read(authProvider).user;

    await ref.read(assignmentProvider.notifier).respondToRejection(
      widget.assignmentId,
      widget.item.index,
      responseComment: _commentController.text.trim(),
      photoUrl: _pickedImageName,
      completedBy: user?.fullName,
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
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

              // ① Status header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    if (widget.item.description != null &&
                        widget.item.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.item.description!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Status badge (수정요청)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_note,
                              size: 16, color: Color(0xFFF59E0B)),
                          SizedBox(width: 6),
                          Text(
                            '수정요청',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Requester + time
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          widget.item.rejectedBy ?? '-',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.access_time,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          widget.item.rejectedAtDisplay ?? '-',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),

              // Scrollable content (photo + comment first, timeline collapsed)
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ② Photo section (if requires photo)
                    if (widget.item.requiresPhoto) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text(
                                  '인증 사진',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.camera_alt_outlined,
                                    size: 16, color: AppColors.textMuted),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_pickedImageBytes != null)
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      _pickedImageBytes!,
                                      width: double.infinity,
                                      height: 200,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () => setState(() {
                                        _pickedImageBytes = null;
                                        _pickedImageName = null;
                                      }),
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close,
                                            size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _takePhoto,
                                      icon: const Icon(Icons.camera_alt, size: 16),
                                      label: const Text('촬영'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.accent,
                                        side: const BorderSide(color: AppColors.accent),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _pickImage,
                                      icon: const Icon(Icons.photo_library, size: 16),
                                      label: const Text('갤러리'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.textSecondary,
                                        side: const BorderSide(color: AppColors.border),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Response comment (required)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text(
                                '처리 내용',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(
                                '*',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '피드백에 대한 처리 내용을 기록해주세요.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _commentController,
                            maxLines: 4,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.text,
                            ),
                            decoration: InputDecoration(
                              hintText: '예: 우유 유통기한 재확인 완료했습니다.',
                              hintStyle: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textMuted,
                              ),
                              filled: true,
                              fillColor: AppColors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.accent),
                              ),
                              contentPadding: const EdgeInsets.all(14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ③ Collapsible timeline (처리 이력)
                    GestureDetector(
                      onTap: () =>
                          setState(() => _isHistoryExpanded = !_isHistoryExpanded),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isHistoryExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '처리 이력 (${widget.item.fullHistory.length}건)',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            if (!_isHistoryExpanded)
                              const Text(
                                '탭하여 펼치기',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Expandable timeline content
                    if (_isHistoryExpanded) ...[
                      const SizedBox(height: 12),
                      ...widget.item.fullHistory.map((event) {
                        final events = widget.item.fullHistory;
                        final isLastEvent = event == events.last;
                        return _TimelineStepCard(
                          type: event.type,
                          by: event.by,
                          at: event.atDisplay,
                          comment: event.comment,
                          photoUrls: event.photoUrls,
                          isLast: isLastEvent,
                        );
                      }),
                    ],
                  ],
                ),
              ),

              // Submit button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canSubmit ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.border,
                        disabledForegroundColor: AppColors.textMuted,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.replay, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  '재제출',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
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

// ─── Item detail sheet (approval workflow log) ────────────────────────────────

class _ItemDetailSheet extends StatelessWidget {
  final ChecklistItem item;

  const _ItemDetailSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final events = item.fullHistory;
    final hasPending = item.isRejected && !item.isResolved;
    final totalSteps = events.length + (hasPending ? 1 : 0);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
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

              // ① Status header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Status badge (most prominent)
                    _buildCurrentStatusBadge(),
                    const SizedBox(height: 10),
                    // Submitter + time
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          item.completedBy ?? '-',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.access_time,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          item.completedAtDisplay ?? '-',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.border),

              // ② Timeline (scrollable)
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  itemCount: totalSteps,
                  itemBuilder: (context, index) {
                    if (hasPending && index == events.length) {
                      return const _TimelineStepCard(
                        type: 'pending',
                        comment: '재수행 대기중',
                        isLast: true,
                      );
                    }
                    final event = events[index];
                    return _TimelineStepCard(
                      type: event.type,
                      by: event.by,
                      at: event.atDisplay,
                      comment: event.comment,
                      photoUrls: event.photoUrls,
                      isLast: index == totalSteps - 1,
                    );
                  },
                ),
              ),

              // ③ Close button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppColors.bg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        '닫기',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
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

  Widget _buildCurrentStatusBadge() {
    final String label;
    final Color color;
    final Color bg;
    final IconData icon;

    if (item.isRejected && !item.isResolved) {
      label = '수정요청';
      color = const Color(0xFFF59E0B);
      bg = const Color(0xFFFFFBEB);
      icon = Icons.edit_note;
    } else if (item.isResolved) {
      label = '재제출 완료';
      color = const Color(0xFF6C5CE7);
      bg = const Color(0xFFF0EEFF);
      icon = Icons.replay;
    } else if (item.isCompleted) {
      label = '제출 완료';
      color = const Color(0xFF10B981);
      bg = const Color(0xFFD1FAE5);
      icon = Icons.check_circle;
    } else {
      label = '미제출';
      color = const Color(0xFF9CA3AF);
      bg = const Color(0xFFF9FAFB);
      icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Timeline step card (approval workflow log) ──────────────────────────────

class _TimelineStepCard extends StatelessWidget {
  final String type; // 'completed', 'rejected', 'responded', 'pending'
  final String? by;
  final String? at;
  final String? comment;
  final List<String> photoUrls;
  final bool isLast;

  const _TimelineStepCard({
    required this.type,
    this.by,
    this.at,
    this.comment,
    this.photoUrls = const [],
    this.isLast = false,
  });

  // Status colors (제출=파랑, 수정요청=주황, 재제출=보라, 대기=회색)
  static const _submitColor = Color(0xFF3B82F6);
  static const _submitBg = Color(0xFFEFF6FF);
  static const _changeReqColor = Color(0xFFF59E0B);
  static const _changeReqBg = Color(0xFFFFFBEB);
  static const _resubmitColor = Color(0xFF6C5CE7);
  static const _resubmitBg = Color(0xFFF0EEFF);
  static const _pendingColor = Color(0xFF9CA3AF);
  static const _pendingBg = Color(0xFFF9FAFB);

  Color get _dotColor {
    switch (type) {
      case 'completed':
        return _submitColor;
      case 'rejected':
        return _changeReqColor;
      case 'responded':
        return _resubmitColor;
      case 'pending':
        return _pendingColor;
      default:
        return _pendingColor;
    }
  }

  Color get _cardBg {
    switch (type) {
      case 'completed':
        return _submitBg;
      case 'rejected':
        return _changeReqBg;
      case 'responded':
        return _resubmitBg;
      case 'pending':
        return _pendingBg;
      default:
        return _pendingBg;
    }
  }

  String get _label {
    switch (type) {
      case 'completed':
        return '제출';
      case 'rejected':
        return '수정요청';
      case 'responded':
        return '재제출';
      case 'pending':
        return '대기중';
      default:
        return type;
    }
  }

  IconData get _icon {
    switch (type) {
      case 'completed':
        return Icons.upload_file;
      case 'rejected':
        return Icons.edit_note;
      case 'responded':
        return Icons.replay;
      case 'pending':
        return Icons.schedule;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline rail: dot + vertical line
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.only(top: 4),
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Card content
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _dotColor.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badge + time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _dotColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_icon, size: 12, color: _dotColor),
                            const SizedBox(width: 4),
                            Text(
                              _label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _dotColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (at != null)
                        Text(
                          at!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),

                  // Author
                  if (by != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          by!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Comment
                  if (comment != null && comment!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        comment!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.text,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],

                  // Photos
                  if (photoUrls.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _PhotoCarousel(photoUrls: photoUrls),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Photo carousel ───────────────────────────────────────────────────────────

class _PhotoCarousel extends StatefulWidget {
  final List<String> photoUrls;

  const _PhotoCarousel({required this.photoUrls});

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.photoUrls.length == 1) {
      return _buildSinglePhoto(context, widget.photoUrls[0]);
    }

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            itemCount: widget.photoUrls.length,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _buildPhoto(context, widget.photoUrls[index], index),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        // Page indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.photoUrls.length,
            (i) => Container(
              width: i == _currentPage ? 16 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: i == _currentPage
                    ? AppColors.accent
                    : AppColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSinglePhoto(BuildContext context, String url) {
    return GestureDetector(
      onTap: () => _openFullScreen(context, widget.photoUrls, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: double.infinity,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _photoErrorWidget(),
          loadingBuilder: _photoLoadingBuilder,
        ),
      ),
    );
  }

  Widget _buildPhoto(BuildContext context, String url, int index) {
    return GestureDetector(
      onTap: () => _openFullScreen(context, widget.photoUrls, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: double.infinity,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _photoErrorWidget(),
          loadingBuilder: _photoLoadingBuilder,
        ),
      ),
    );
  }

  void _openFullScreen(
      BuildContext context, List<String> urls, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => _FullScreenPhotoViewer(
          photoUrls: urls,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _photoErrorWidget() {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, size: 28, color: AppColors.textMuted),
          SizedBox(height: 4),
          Text('사진을 불러올 수 없습니다',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _photoLoadingBuilder(
      BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
    if (loadingProgress == null) return child;
    return Container(
      width: double.infinity,
      height: 160,
      color: AppColors.bg,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

// ─── Full screen photo viewer (multi-photo swipe) ─────────────────────────────

class _FullScreenPhotoViewer extends StatefulWidget {
  final List<String> photoUrls;
  final int initialIndex;

  const _FullScreenPhotoViewer({
    required this.photoUrls,
    this.initialIndex = 0,
  });

  @override
  State<_FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<_FullScreenPhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.photoUrls.length;
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Stack(
        children: [
          // Photo pager
          PageView.builder(
            controller: _pageController,
            itemCount: total,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      widget.photoUrls[index],
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_outlined,
                              size: 48, color: Colors.white54),
                          SizedBox(height: 8),
                          Text(
                            '사진을 불러올 수 없습니다',
                            style:
                                TextStyle(fontSize: 14, color: Colors.white54),
                          ),
                        ],
                      ),
                      loadingBuilder: (_, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),

          // Page indicator (only when multiple photos)
          if (total > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / $total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
