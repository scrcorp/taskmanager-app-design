import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../utils/toast_manager.dart';
import '../../widgets/app_modal.dart';

// ═══════════════════════════════════════════════════════════════
//  Enums & Models
// ═══════════════════════════════════════════════════════════════

enum _OjtCategory { all, hygiene, safety, operation }

enum _ContentType { video, document }

class _OjtContent {
  final String id;
  final String title;
  final _OjtCategory category;
  final _ContentType type;
  final int? durationMinutes;
  bool completed;

  _OjtContent({
    required this.id,
    required this.title,
    required this.category,
    required this.type,
    this.durationMinutes,
    this.completed = false,
  });
}

// ═══════════════════════════════════════════════════════════════
//  Main Screen
// ═══════════════════════════════════════════════════════════════

class OjtScreen extends ConsumerStatefulWidget {
  const OjtScreen({super.key});
  @override
  ConsumerState<OjtScreen> createState() => _OjtScreenState();
}

class _OjtScreenState extends ConsumerState<OjtScreen> {
  _OjtCategory _selectedCategory = _OjtCategory.all;
  bool _allCompleteShown = false;

  List<_OjtContent> get _filteredContents {
    if (_selectedCategory == _OjtCategory.all) return _contents;
    return _contents.where((c) => c.category == _selectedCategory).toList();
  }

  int get _completedCount => _contents.where((c) => c.completed).length;
  int get _totalCount => _contents.length;
  double get _progressRatio => _totalCount > 0 ? _completedCount / _totalCount : 0;

  Future<void> _toggleCompletion(_OjtContent content) async {
    if (content.completed) {
      // Undo completion
      setState(() => content.completed = false);
      _allCompleteShown = false;
      ToastManager().info(context, '완료 취소되었습니다.');
      return;
    }

    final result = await AppModal.show(
      context,
      title: '학습 완료',
      message: '"${content.title}" 학습을 완료하셨습니까?',
      type: ModalType.confirm,
      confirmText: '완료',
      cancelText: '취소',
    );
    if (result == true && mounted) {
      setState(() => content.completed = true);
      ToastManager().success(context, '학습 완료!');

      if (_completedCount == _totalCount && !_allCompleteShown) {
        _allCompleteShown = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ToastManager().success(context, '모든 OJT 학습을 완료했습니다! 🎉');
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredContents;

    return Column(
      children: [
        // Progress card
        _ProgressCard(
          completed: _completedCount,
          total: _totalCount,
          ratio: _progressRatio,
        ),

        // Category filter
        _CategoryFilter(
          selected: _selectedCategory,
          onChanged: (c) => setState(() => _selectedCategory = c),
          categoryCounts: {
            _OjtCategory.all: _totalCount,
            _OjtCategory.hygiene: _contents.where((c) => c.category == _OjtCategory.hygiene).length,
            _OjtCategory.safety: _contents.where((c) => c.category == _OjtCategory.safety).length,
            _OjtCategory.operation: _contents.where((c) => c.category == _OjtCategory.operation).length,
          },
        ),

        // Content list
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_outlined, size: 48, color: AppColors.border),
                      SizedBox(height: 12),
                      Text('해당 카테고리에 콘텐츠가 없습니다.',
                          style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _ContentCard(
                    content: filtered[i],
                    onToggle: () => _toggleCompletion(filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Mock Data
  // ═══════════════════════════════════════════════════════════════

  static final List<_OjtContent> _contents = [
    _OjtContent(
      id: 'ojt1', title: '식품 위생 기초', category: _OjtCategory.hygiene,
      type: _ContentType.video, durationMinutes: 15, completed: true,
    ),
    _OjtContent(
      id: 'ojt2', title: '개인 위생 관리 가이드', category: _OjtCategory.hygiene,
      type: _ContentType.document, completed: true,
    ),
    _OjtContent(
      id: 'ojt3', title: 'HACCP 기본 원칙', category: _OjtCategory.hygiene,
      type: _ContentType.video, durationMinutes: 20, completed: true,
    ),
    _OjtContent(
      id: 'ojt4', title: '매장 안전 수칙', category: _OjtCategory.safety,
      type: _ContentType.video, durationMinutes: 18,
    ),
    _OjtContent(
      id: 'ojt5', title: '소화기 사용법', category: _OjtCategory.safety,
      type: _ContentType.document,
    ),
    _OjtContent(
      id: 'ojt6', title: '응급 상황 대처 매뉴얼', category: _OjtCategory.safety,
      type: _ContentType.document,
    ),
    _OjtContent(
      id: 'ojt7', title: 'POS 시스템 사용법', category: _OjtCategory.operation,
      type: _ContentType.video, durationMinutes: 25,
    ),
    _OjtContent(
      id: 'ojt8', title: '고객 응대 매뉴얼', category: _OjtCategory.operation,
      type: _ContentType.document,
    ),
    _OjtContent(
      id: 'ojt9', title: '개점/폐점 절차', category: _OjtCategory.operation,
      type: _ContentType.video, durationMinutes: 12,
    ),
    _OjtContent(
      id: 'ojt10', title: '재고 관리 기초', category: _OjtCategory.operation,
      type: _ContentType.document, completed: true,
    ),
  ];
}

// ═══════════════════════════════════════════════════════════════
//  Progress Card
// ═══════════════════════════════════════════════════════════════

class _ProgressCard extends StatelessWidget {
  final int completed;
  final int total;
  final double ratio;

  const _ProgressCard({
    required this.completed,
    required this.total,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (ratio * 100).toInt();
    final isAllDone = completed == total && total > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isAllDone ? AppColors.successBg : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isAllDone ? AppColors.success.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAllDone ? Icons.emoji_events_rounded : Icons.school_rounded,
                size: 20,
                color: isAllDone ? AppColors.success : AppColors.accent,
              ),
              const SizedBox(width: 8),
              Text(
                isAllDone ? '모든 학습 완료!' : 'OJT 진행률',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isAllDone ? AppColors.success : AppColors.text,
                ),
              ),
              const Spacer(),
              Text(
                '$completed/$total 완료',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isAllDone ? AppColors.success : AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: isAllDone
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.bg,
              color: isAllDone ? AppColors.success : AppColors.accent,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$percent%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isAllDone ? AppColors.success : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Category Filter
// ═══════════════════════════════════════════════════════════════

class _CategoryFilter extends StatelessWidget {
  final _OjtCategory selected;
  final ValueChanged<_OjtCategory> onChanged;
  final Map<_OjtCategory, int> categoryCounts;

  const _CategoryFilter({
    required this.selected,
    required this.onChanged,
    required this.categoryCounts,
  });

  static const _labels = {
    _OjtCategory.all: '전체',
    _OjtCategory.hygiene: '위생교육',
    _OjtCategory.safety: '안전교육',
    _OjtCategory.operation: '매장운영',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: _OjtCategory.values.map((cat) {
          final isActive = selected == cat;
          final count = categoryCounts[cat] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? AppColors.accent : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _labels[cat]!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isActive ? Colors.white70 : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Content Card
// ═══════════════════════════════════════════════════════════════

class _ContentCard extends StatelessWidget {
  final _OjtContent content;
  final VoidCallback onToggle;

  const _ContentCard({required this.content, required this.onToggle});

  static const _categoryLabels = {
    _OjtCategory.hygiene: '위생교육',
    _OjtCategory.safety: '안전교육',
    _OjtCategory.operation: '매장운영',
  };

  static const _categoryColors = {
    _OjtCategory.hygiene: AppColors.success,
    _OjtCategory.safety: AppColors.warning,
    _OjtCategory.operation: AppColors.accent,
  };

  @override
  Widget build(BuildContext context) {
    final catLabel = _categoryLabels[content.category] ?? '';
    final catColor = _categoryColors[content.category] ?? AppColors.accent;
    final isVideo = content.type == _ContentType.video;
    final typeIcon = isVideo
        ? Icons.play_circle_outline_rounded
        : Icons.description_outlined;
    final typeLabel = isVideo ? '동영상' : '문서';
    final metaParts = [catLabel, typeLabel];
    if (isVideo && content.durationMinutes != null) {
      metaParts.add('${content.durationMinutes}분');
    }

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: content.completed
              ? AppColors.successBg.withValues(alpha: 0.5)
              : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: content.completed
                ? AppColors.success.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: content.completed
                    ? AppColors.success.withValues(alpha: 0.1)
                    : catColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                typeIcon,
                size: 22,
                color: content.completed ? AppColors.success : catColor,
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: content.completed ? AppColors.textSecondary : AppColors.text,
                      decoration: content.completed ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metaParts.join(' · '),
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Completion check
            Icon(
              content.completed
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 26,
              color: content.completed ? AppColors.success : AppColors.border,
            ),
          ],
        ),
      ),
    );
  }
}
