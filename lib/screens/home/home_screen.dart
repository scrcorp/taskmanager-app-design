import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/assignment.dart';
import '../../models/task.dart';
import '../../providers/auth_provider.dart';
import '../../providers/assignment_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/announcement_provider.dart';

String _getGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

List<String> _extractTags(List<Assignment> assignments) {
  final tags = <String>{};
  for (final a in assignments) {
    if (a.store.name.isNotEmpty) tags.add(a.store.name);
    if (a.shift.name.isNotEmpty) tags.add(a.shift.name);
  }
  return tags.toList();
}

int _countDueToday(List<AdditionalTask> tasks) {
  final now = DateTime.now();
  return tasks.where((t) {
    if (t.dueDate == null) return false;
    return t.dueDate!.year == now.year &&
        t.dueDate!.month == now.month &&
        t.dueDate!.day == now.day &&
        t.status != 'completed';
  }).length;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final PageController _bannerController;
  Timer? _bannerTimer;
  int _currentBannerPage = 0;
  int _bannerCount = 0;

  @override
  void initState() {
    super.initState();
    _bannerController = PageController();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    Future.microtask(() {
      ref.read(assignmentProvider.notifier).loadAssignments(today);
      ref.read(taskProvider.notifier).loadTasks();
      ref.read(announcementProvider.notifier).loadAnnouncements();
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _startBannerAutoScroll(int count) {
    if (_bannerTimer?.isActive == true && _bannerCount == count) return;
    _bannerCount = count;
    _bannerTimer?.cancel();
    if (count <= 1) return;
    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      _currentBannerPage = (_currentBannerPage + 1) % count;
      _bannerController.animateToPage(
        _currentBannerPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final assignments = ref.watch(assignmentProvider);
    final tasks = ref.watch(taskProvider);
    final announcements = ref.watch(announcementProvider);
    final today = DateTime.now();

    ref.listen<AssignmentState>(assignmentProvider, (_, next) {
      if (!next.isLoading && next.assignments.length > 1) {
        _startBannerAutoScroll(next.assignments.length);
      } else if (next.isLoading) {
        _bannerTimer?.cancel();
        _bannerTimer = null;
      }
    });

    final greeting = _getGreeting();
    final firstName = user?.firstName ?? 'Staff';
    final tags = _extractTags(assignments.assignments);
    final dueTodayCount = _countDueToday(tasks.tasks);
    final fullName = user?.fullName ?? 'Staff';
    final noticeCount = announcements.announcements.length;

    final String bannerMessage;
    final String bannerSub;
    if (tasks.isLoading) {
      bannerMessage = 'Checking your tasks...';
      bannerSub = 'Loading your schedule.';
    } else if (dueTodayCount > 0) {
      bannerMessage = '$fullName, you have $dueTodayCount task(s) due today.';
      bannerSub = 'Please check and complete them.';
    } else {
      bannerMessage = "$firstName, you're all caught up today!";
      bannerSub = 'Great job keeping on top of things.';
    }

    return RefreshIndicator(
      onRefresh: () async {
        final dateStr = DateFormat('yyyy-MM-dd').format(today);
        await Future.wait([
          ref.read(assignmentProvider.notifier).loadAssignments(dateStr),
          ref.read(taskProvider.notifier).loadTasks(),
          ref.read(announcementProvider.notifier).loadAnnouncements(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Greeting
          _GreetingSection(greeting: greeting, firstName: firstName),
          const SizedBox(height: 12),

          // Hashtag chips
          if (!assignments.isLoading && tags.isNotEmpty)
            _HashtagChips(tags: tags),
          const SizedBox(height: 24),

          // Feature cards: OJT + Notice (2-column)
          Row(
            children: [
              Expanded(
                child: _FeatureCard(
                  icon: Icons.school_outlined,
                  title: 'OJT',
                  subtitle: '교육 자료',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Coming soon'),
                      duration: Duration(seconds: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FeatureCard(
                  icon: Icons.campaign_outlined,
                  title: '공지사항',
                  subtitle: 'Notice',
                  badge: noticeCount > 0 ? noticeCount : null,
                  onTap: () => context.go('/notices'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Today's work section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '오늘의 업무',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              if (!assignments.isLoading && assignments.assignments.isNotEmpty)
                Text(
                  '${assignments.assignments.length}건',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Auto-scrolling assignment banner
          _AssignmentBanner(
            assignments: assignments.assignments,
            isLoading: assignments.isLoading,
            controller: _bannerController,
            currentPage: _currentBannerPage,
            onPageChanged: (page) => setState(() => _currentBannerPage = page),
            onTap: (id) => context.push('/work/$id'),
          ),
          const SizedBox(height: 24),

          // Announcement banner
          _AnnouncementBanner(
            message: bannerMessage,
            subMessage: bannerSub,
            onTap: () => context.go('/tasks'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── Greeting ────────────────────────────────────────────────────────────────

class _GreetingSection extends StatelessWidget {
  final String greeting;
  final String firstName;

  const _GreetingSection({required this.greeting, required this.firstName});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting,',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          firstName,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

// ─── Hashtag chips ───────────────────────────────────────────────────────────

class _HashtagChips extends StatelessWidget {
  final List<String> tags;

  const _HashtagChips({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.accentBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '#$tag',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Feature card (OJT / Notice) ─────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int? badge;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accentBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: AppColors.accent),
                ),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Assignment banner (auto-scroll PageView) ─────────────────────────────────

class _AssignmentBanner extends StatelessWidget {
  final List<Assignment> assignments;
  final bool isLoading;
  final PageController controller;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onTap;

  const _AssignmentBanner({
    required this.assignments,
    required this.isLoading,
    required this.controller,
    required this.currentPage,
    required this.onPageChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (assignments.isEmpty) {
      return Container(
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            '오늘 배정된 업무가 없습니다',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 110,
          child: PageView.builder(
            controller: controller,
            onPageChanged: onPageChanged,
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              final a = assignments[index];
              final total = a.checklistSnapshot?.totalItems ?? 0;
              final completed = a.checklistSnapshot?.completedItems ?? 0;
              final progress = total > 0 ? completed / total : 0.0;

              return GestureDetector(
                onTap: () => onTap(a.id),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              a.label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(status: a.statusLabel, statusCode: a.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
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
                      const SizedBox(height: 6),
                      Text(
                        '$completed / $total 완료',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (assignments.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(assignments.length, (index) {
              final active = currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? AppColors.accent : AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final String statusCode;

  const _StatusBadge({required this.status, required this.statusCode});

  Color get _bgColor {
    switch (statusCode) {
      case 'in_progress':
        return AppColors.accentBg;
      case 'completed':
        return AppColors.successBg;
      default:
        return AppColors.border;
    }
  }

  Color get _textColor {
    switch (statusCode) {
      case 'in_progress':
        return AppColors.accent;
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _textColor,
        ),
      ),
    );
  }
}

// ─── Announcement banner ──────────────────────────────────────────────────────

class _AnnouncementBanner extends StatelessWidget {
  final String message;
  final String subMessage;
  final VoidCallback onTap;

  const _AnnouncementBanner({
    required this.message,
    required this.subMessage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.accentBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.campaign_outlined, size: 20, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subMessage,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
