import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/task_provider.dart';
import '../../models/task.dart';
import '../../utils/date_utils.dart';
import '../../utils/toast_manager.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const TaskDetailScreen({super.key, required this.id});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _commentController = TextEditingController();
  final _commentFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(taskProvider.notifier).loadTask(widget.id));
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return AppColors.danger;
      case 'high':
        return AppColors.warning;
      case 'normal':
        return AppColors.accent;
      case 'low':
        return AppColors.textMuted;
      default:
        return AppColors.textMuted;
    }
  }

  Color _priorityBgColor(String priority) {
    switch (priority) {
      case 'urgent':
        return AppColors.dangerBg;
      case 'high':
        return AppColors.warningBg;
      case 'normal':
        return AppColors.accentBg;
      case 'low':
        return AppColors.bg;
      default:
        return AppColors.bg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskProvider);
    final task = state.selected;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Task Detail'),
      ),
      body: state.isLoading && task == null
          ? const Center(child: CircularProgressIndicator())
          : task == null
              ? Center(
                  child: Text(state.error ?? 'Task not found',
                      style: const TextStyle(color: AppColors.textMuted)),
                )
              : _buildContent(task, state.isLoading),
    );
  }

  Widget _buildContent(AdditionalTask task, bool isLoading) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Card ──
                _buildHeaderCard(task),
                const SizedBox(height: 8),
                // ── Info Section ──
                _buildInfoSection(task),
                const SizedBox(height: 8),
                // ── Description ──
                if (task.description != null && task.description!.isNotEmpty)
                  _buildDescriptionSection(task),
                // ── Assignees ──
                if (task.assignees.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildAssigneesSection(task),
                ],
                // ── Comments ──
                const SizedBox(height: 8),
                _buildCommentsSection(task),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        // ── Comment Input ──
        _buildCommentInput(task),
        // ── Mark Complete Button ──
        if (task.status != 'completed')
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              color: AppColors.white,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          await ref
                              .read(taskProvider.notifier)
                              .completeTask(widget.id);
                          if (mounted) {
                            ToastManager().success(context, 'Task marked as complete');
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Mark Complete'),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Header Card: title, priority, status ──
  Widget _buildHeaderCard(AdditionalTask task) {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Priority + Status row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _priorityBgColor(task.priority),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  task.priorityLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _priorityColor(task.priority),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: task.status == 'completed'
                      ? AppColors.successBg
                      : task.status == 'in_progress'
                          ? AppColors.accentBg
                          : AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  task.statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: task.status == 'completed'
                        ? AppColors.success
                        : task.status == 'in_progress'
                            ? AppColors.accent
                            : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Title
          Text(
            task.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          if (task.store?.name != null) ...[
            const SizedBox(height: 4),
            Text(
              task.store!.name,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
          // Labels
          if (task.labels.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: task.labels.map((label) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          // Completion info
          if (task.status == 'completed' && task.completedAt != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 18, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Completed by ${task.completedByName ?? 'Unknown'} · ${formatActionTime(task.completedAt!)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Info Section: dates, creator ──
  Widget _buildInfoSection(AdditionalTask task) {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (task.startDate != null)
            _DetailRow(
              icon: Icons.play_circle_outline,
              label: 'Start time',
              value: formatDateTime(task.startDate!),
            ),
          if (task.startDate != null && task.dueDate != null)
            const SizedBox(height: 14),
          if (task.dueDate != null)
            _DetailRow(
              icon: Icons.schedule,
              label: 'Due date',
              value: formatDateTime(task.dueDate!),
              valueColor: task.dueDate!.isBefore(DateTime.now()) && task.status != 'completed'
                  ? AppColors.danger
                  : null,
            ),
          if (task.dueDate != null || task.startDate != null)
            const _SectionDivider(),
          if (task.assignees.isNotEmpty)
            _DetailRow(
              icon: Icons.people_outline,
              label: 'Assigned to',
              value: task.assignees.map((a) => a.fullName ?? 'Unknown').join(', '),
            ),
          if (task.assignees.isNotEmpty)
            const _SectionDivider(),
          if (task.createdByName != null)
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Created by',
              value: task.createdByName!,
            ),
          if (task.createdAt != null) ...[
            const SizedBox(height: 14),
            _DetailRow(
              icon: Icons.access_time,
              label: 'Created at',
              value: formatDateTime(task.createdAt!),
            ),
          ],
        ],
      ),
    );
  }

  // ── Description Section ──
  Widget _buildDescriptionSection(AdditionalTask task) {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            task.description!,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Assignees Section ──
  Widget _buildAssigneesSection(AdditionalTask task) {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assignees (${task.assignees.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          ...task.assignees.map((assignee) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: assignee.isCompleted
                        ? AppColors.successBg
                        : AppColors.accentBg,
                    child: Icon(
                      assignee.isCompleted ? Icons.check : Icons.person,
                      size: 16,
                      color: assignee.isCompleted
                          ? AppColors.success
                          : AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignee.fullName ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.text,
                          ),
                        ),
                        if (assignee.isCompleted && assignee.completedAt != null)
                          Text(
                            'Done ${formatActionTime(assignee.completedAt!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (assignee.isCompleted)
                    const Icon(Icons.check_circle, size: 18, color: AppColors.success)
                  else
                    const Icon(Icons.radio_button_unchecked, size: 18, color: AppColors.textMuted),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Comments Section ──
  Widget _buildCommentsSection(AdditionalTask task) {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comments (${task.comments.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          if (task.comments.isEmpty) ...[
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Icon(Icons.chat_bubble_outline, size: 32, color: AppColors.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  const Text(
                    'No comments yet',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Be the first to leave a comment',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            const SizedBox(height: 16),
            ...task.comments.map((comment) => _CommentTile(comment: comment)),
          ],
        ],
      ),
    );
  }

  // ── Comment Input Bar ──
  Widget _buildCommentInput(AdditionalTask task) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        bottom: task.status == 'completed',
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.accentBg,
              child: const Icon(Icons.person, size: 16, color: AppColors.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocus,
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  filled: true,
                  fillColor: AppColors.bg,
                ),
                style: const TextStyle(fontSize: 14),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitComment(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: AppColors.accent),
              onPressed: _submitComment,
            ),
          ],
        ),
      ),
    );
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _commentController.clear();
    _commentFocus.unfocus();
    ref.read(taskProvider.notifier).addComment(widget.id, text: text);
  }
}

// ── Detail Row Widget ──
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor ?? AppColors.text,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Section Divider ──
class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
    );
  }
}

// ── Comment Tile ──
class _CommentTile extends StatelessWidget {
  final TaskComment comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = comment.userId == 'user-current';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isCurrentUser ? AppColors.accentBg : AppColors.bg,
            child: Text(
              comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isCurrentUser ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo(comment.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                if (comment.text != null && comment.text!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    comment.text!,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.text,
                    ),
                  ),
                ],
                if (comment.imageUrl != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      color: AppColors.bg,
                      child: const Center(
                        child: Icon(Icons.image, size: 32, color: AppColors.textMuted),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                // Like + Reply row
                Row(
                  children: [
                    Icon(
                      comment.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 14,
                      color: comment.isLiked ? AppColors.danger : AppColors.textMuted,
                    ),
                    if (comment.likes > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${comment.likes}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                    const SizedBox(width: 16),
                    const Icon(Icons.reply, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    const Text(
                      'Reply',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
                // Replies
                if (comment.replies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: comment.replies
                          .map((reply) => _CommentTile(comment: reply))
                          .toList(),
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
