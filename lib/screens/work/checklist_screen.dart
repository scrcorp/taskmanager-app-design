import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/assignment_provider.dart';
import '../../models/checklist.dart';
import '../../utils/date_utils.dart';
import '../../utils/toast_manager.dart';

class ChecklistScreen extends ConsumerStatefulWidget {
  final String id;
  const ChecklistScreen({super.key, required this.id});
  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  bool _celebrationShown = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(assignmentProvider.notifier).loadAssignment(widget.id);
    });
  }

  void _showCompletionToast() {
    if (_celebrationShown) return;
    _celebrationShown = true;
    ToastManager().success(context, 'All tasks completed! Great work!');
  }

  @override
  Widget build(BuildContext context) {
    final assignmentState = ref.watch(assignmentProvider);
    final assignment = assignmentState.selected;

    // Check for all-completed state after build
    if (assignment != null &&
        assignment.checklistSnapshot != null &&
        assignment.checklistSnapshot!.isAllCompleted &&
        !_celebrationShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCompletionToast();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Checklist'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: AppColors.text,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: assignmentState.isLoading || assignment == null
          ? const Center(child: CircularProgressIndicator())
          : assignmentState.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Failed to load assignment',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(assignmentProvider.notifier)
                                .loadAssignment(widget.id);
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref
                        .read(assignmentProvider.notifier)
                        .loadAssignment(widget.id);
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Assignment header card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              assignment.label,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formatFixedDateWithDay(assignment.workDate),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Progress section
                            _buildProgressSection(assignment),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Checklist items header
                      Row(
                        children: [
                          const Text(
                            'Checklist Items',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (assignment.checklistSnapshot != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${assignment.checklistSnapshot!.totalItems}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Checklist items
                      if (assignment.checklistSnapshot == null ||
                          assignment.checklistSnapshot!.items.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Center(
                            child: Text(
                              'No checklist items',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: List.generate(
                              assignment.checklistSnapshot!.items.length,
                              (index) {
                                final item =
                                    assignment.checklistSnapshot!.items[index];
                                return Column(
                                  children: [
                                    if (index > 0)
                                      const Divider(
                                        height: 1,
                                        color: AppColors.border,
                                      ),
                                    _ChecklistItemTile(
                                      item: item,
                                      onToggle: () {
                                        ref
                                            .read(
                                                assignmentProvider.notifier)
                                            .toggleChecklistItem(
                                              widget.id,
                                              item.index,
                                              !item.isCompleted,
                                            );
                                      },
                                      onTapDetail: () {
                                        _showItemDetailSheet(context, item);
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  void _showItemDetailSheet(BuildContext context, ChecklistItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemDetailSheet(item: item),
    );
  }

  Widget _buildProgressSection(assignment) {
    final snapshot = assignment.checklistSnapshot;
    final completed = snapshot?.completedItems ?? 0;
    final total = snapshot?.totalItems ?? 0;
    final progress = total > 0 ? completed / total : 0.0;
    final isComplete = progress >= 1.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isComplete ? 'Completed' : 'In Progress',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isComplete ? AppColors.success : AppColors.accent,
              ),
            ),
            Text(
              '$completed/$total items',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(
              isComplete ? AppColors.success : AppColors.accent,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChecklistItemTile extends StatelessWidget {
  final ChecklistItem item;
  final VoidCallback onToggle;
  final VoidCallback onTapDetail;

  const _ChecklistItemTile({
    required this.item,
    required this.onToggle,
    required this.onTapDetail,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      onLongPress: onTapDetail,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                width: 24,
                height: 24,
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
                    ? const Icon(Icons.refresh, size: 14, color: AppColors.warning)
                    : item.isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
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
                      if (item.isRejected)
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
                    const SizedBox(height: 4),
                    Text(
                      item.description!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  if (item.isCompleted && !item.isRejected && item.completedAtDisplay != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Completed ${item.completedAtDisplay}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                  // Inline rejection feedback (방안 A)
                  if (item.isRejected && item.rejectionComment != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onTapDetail,
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
                            if (item.rejectionComment!.length > 60) ...[
                              const SizedBox(height: 2),
                              const Text(
                                '자세히 보기',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
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

/// 아이템 상세 바텀시트 — chat-like timeline
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
                    _buildCurrentStatusBadge(),
                    const SizedBox(height: 10),
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
  final String type;
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.photoUrls.length,
            (i) => Container(
              width: i == _currentPage ? 16 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: i == _currentPage ? AppColors.accent : AppColors.border,
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
                          Text('사진을 불러올 수 없습니다',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.white54)),
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
