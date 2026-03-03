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
    if (workDate != null) {
      final filterDate = DateTime.parse(workDate);
      result = result.where((a) =>
        a.workDate.year == filterDate.year &&
        a.workDate.month == filterDate.month &&
        a.workDate.day == filterDate.day
      ).toList();
    }
    if (status != null) {
      result = result.where((a) => a.status == status).toList();
    }
    return result;
  }

  Future<List<Assignment>> getPastAssignments() async {
    await Future.delayed(const Duration(milliseconds: 200));
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    return mockAssignments
        .where((a) => a.workDate.isBefore(todayStart))
        .toList()
      ..sort((a, b) => b.workDate.compareTo(a.workDate));
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

  Future<void> respondToRejection(
    String assignmentId,
    int itemIndex, {
    String? responseComment,
    String? photoUrl,
    String? completedBy,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final idx = mockAssignments.indexWhere((a) => a.id == assignmentId);
    if (idx == -1) return;
    final current = mockAssignments[idx];
    if (current.checklistSnapshot == null) return;

    final updatedItems = current.checklistSnapshot!.items.map((item) {
      if (item.index == itemIndex) {
        return item.copyWith(
          isCompleted: true,
          isRejected: false,
          completedAt: _formatNow(),
          completedTz: DateTime.now().timeZoneName,
          completedBy: completedBy,
          photoUrl: photoUrl,
          responseComment: responseComment,
          respondedAt: _formatNow(),
          respondedBy: completedBy,
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
  // ── Today ──────────────────────────────────────────────────
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
        ChecklistItem(index: 0, title: 'Check espresso machine pressure', description: 'Ensure pressure gauge reads 9 bar', verificationType: 'none', isCompleted: true, completedAt: '2026-03-03T09:15', completedTz: 'KST', completedBy: 'park sung min', sortOrder: 0),
        ChecklistItem(index: 1, title: 'Prepare milk station', description: 'Fill milk pitchers, check dairy expiry dates', verificationType: 'comment', isCompleted: true, completedAt: '2026-03-03T09:20', completedTz: 'KST', completedBy: 'park sung min', comment: 'All pitchers filled, expiry OK', sortOrder: 1),
        ChecklistItem(index: 2, title: 'Stock cups and lids', description: 'Ensure at least 50 of each size', verificationType: 'none', isCompleted: false, sortOrder: 2),
        ChecklistItem(index: 3, title: 'Clean counter area', description: 'Wipe all surfaces, sanitize equipment', verificationType: 'photo', isCompleted: false, sortOrder: 3),
        ChecklistItem(index: 4, title: 'Set display pastries', description: 'Arrange fresh pastries in display case', verificationType: 'photo_comment', isCompleted: false, sortOrder: 4),
        ChecklistItem(index: 5, title: 'Turn on signage & music', verificationType: 'none', isCompleted: false, sortOrder: 5),
      ],
    ),
  ),

  // ── Today: Bistro Garden ─────────────────────────────────────
  Assignment(
    id: 'asgn-002',
    store: const Store(id: 'store-002', name: 'Bistro Garden'),
    shift: const ShiftInfo(id: 'shift-002', name: 'Evening (17:00-22:00)'),
    position: const PositionInfo(id: 'pos-002', name: 'Server'),
    status: 'assigned',
    workDate: DateTime.now(),
    checklistSnapshot: ChecklistSnapshot(
      templateId: 'tmpl-002',
      templateName: 'Server Evening Setup',
      items: const [
        ChecklistItem(index: 0, title: '테이블 세팅 (수저 & 냅킨)', verificationType: 'none', isCompleted: false, sortOrder: 0),
        ChecklistItem(index: 1, title: '예약 리스트 확인', verificationType: 'comment', isCompleted: false, sortOrder: 1),
        ChecklistItem(index: 2, title: '소스 스테이션 보충', verificationType: 'photo_comment', isCompleted: false, sortOrder: 2),
      ],
    ),
  ),

  // ── Today: Seoul Station Bakery ──────────────────────────────
  Assignment(
    id: 'asgn-003',
    store: const Store(id: 'store-003', name: 'Seoul Station Bakery'),
    shift: const ShiftInfo(id: 'shift-003', name: 'Afternoon (14:00-19:00)'),
    position: const PositionInfo(id: 'pos-003', name: 'Baker'),
    status: 'assigned',
    workDate: DateTime.now(),
    checklistSnapshot: ChecklistSnapshot(
      templateId: 'tmpl-003',
      templateName: 'Baker Afternoon Prep',
      items: const [
        ChecklistItem(index: 0, title: '오븐 예열', verificationType: 'photo', isCompleted: false, sortOrder: 0),
        ChecklistItem(index: 1, title: '반죽 발효 상태 확인', verificationType: 'photo_comment', isCompleted: false, sortOrder: 1),
        ChecklistItem(index: 2, title: '제빵 재료 재고 확인', verificationType: 'comment', isCompleted: false, sortOrder: 2),
      ],
    ),
  ),

  // ── Past: Yesterday (3 stores, 3 different scenarios) ──────

  // Store 1: Cafe Bloom — 미처리 rejection (사진 제출했으나 반려)
  Assignment(
    id: 'asgn-past-01',
    store: const Store(id: 'store-001', name: 'Cafe Bloom'),
    shift: const ShiftInfo(id: 'shift-001', name: 'Morning (09:00-14:00)'),
    position: const PositionInfo(id: 'pos-001', name: 'Barista'),
    status: 'completed',
    workDate: DateTime.now().subtract(const Duration(days: 1)),
    checklistSnapshot: ChecklistSnapshot(
      templateId: 'tmpl-001',
      templateName: 'Barista Opening Checklist',
      items: const [
        ChecklistItem(index: 0, title: '에스프레소 머신 압력 확인', verificationType: 'none', isCompleted: true, completedAt: '2026-03-02T09:10', completedTz: 'KST', completedBy: 'park sung min', sortOrder: 0),
        ChecklistItem(index: 1, title: '우유 스테이션 준비', verificationType: 'comment', isCompleted: true, completedAt: '2026-03-02T09:18', completedTz: 'KST', completedBy: 'park sung min', comment: '모든 피처 채움, 유통기한 03/08 확인 완료', sortOrder: 1),
        ChecklistItem(index: 2, title: '컵/뚜껑 재고 확인', verificationType: 'none', isCompleted: true, completedAt: '2026-03-02T09:22', completedTz: 'KST', completedBy: 'park sung min', sortOrder: 2),
        ChecklistItem(
          index: 3, title: '카운터 청소', verificationType: 'photo', sortOrder: 3,
          isCompleted: true, completedAt: '2026-03-02T09:30', completedTz: 'KST', completedBy: 'park sung min',
          photoUrl: 'https://picsum.photos/400/300?random=1',
          isRejected: true, rejectionComment: '카운터 아래쪽 청소가 미흡합니다. 사진을 다시 확인해주세요.', rejectedBy: 'Manager Kim', rejectedAt: '2026-03-02T10:45',
          history: [
            ChecklistItemEvent(type: 'completed', comment: null, photoUrls: ['https://picsum.photos/400/300?random=1'], by: 'park sung min', at: '2026-03-02T09:30'),
            ChecklistItemEvent(type: 'rejected', comment: '카운터 아래쪽 청소가 미흡합니다. 사진을 다시 확인해주세요.', photoUrls: ['https://picsum.photos/400/300?random=10'], by: 'Manager Kim', at: '2026-03-02T10:45'),
          ],
        ),
      ],
    ),
  ),

  // Store 2: Bistro Garden — 2회 반려 후 최종 처리 완료 (채팅형 히스토리)
  Assignment(
    id: 'asgn-past-02',
    store: const Store(id: 'store-002', name: 'Bistro Garden'),
    shift: const ShiftInfo(id: 'shift-002', name: 'Evening (17:00-22:00)'),
    position: const PositionInfo(id: 'pos-002', name: 'Server'),
    status: 'completed',
    workDate: DateTime.now().subtract(const Duration(days: 1)),
    checklistSnapshot: ChecklistSnapshot(
      templateId: 'tmpl-002',
      templateName: 'Server Evening Setup',
      items: const [
        ChecklistItem(index: 0, title: '테이블 세팅 (수저 & 냅킨)', verificationType: 'none', isCompleted: true, completedAt: '2026-03-02T17:15', completedTz: 'KST', completedBy: 'park sung min', sortOrder: 0),
        ChecklistItem(index: 1, title: '예약 리스트 확인', verificationType: 'comment', isCompleted: true, completedAt: '2026-03-02T17:20', completedTz: 'KST', completedBy: 'park sung min', comment: '15팀 예약 확인 완료, VIP 2팀 포함', sortOrder: 1),
        ChecklistItem(
          index: 2, title: '소스 스테이션 보충', verificationType: 'photo_comment', sortOrder: 2,
          isCompleted: true, completedAt: '2026-03-02T19:10', completedTz: 'KST', completedBy: 'park sung min',
          photoUrl: 'https://picsum.photos/400/300?random=22',
          isRejected: false,
          rejectionComment: '소스통이 반만 채워져 있습니다. 전부 채워주세요.',
          rejectedBy: 'Manager Lee', rejectedAt: '2026-03-02T17:50',
          responseComment: '소스통 전부 가득 채웠습니다. 사진 첨부합니다.',
          respondedAt: '2026-03-02T19:10', respondedBy: 'park sung min',
          history: [
            ChecklistItemEvent(type: 'completed', comment: '소스통 채웠습니다.', photoUrls: ['https://picsum.photos/400/300?random=2', 'https://picsum.photos/400/300?random=9'], by: 'park sung min', at: '2026-03-02T17:30'),
            ChecklistItemEvent(type: 'rejected', comment: '소스통이 반만 채워져 있습니다. 전부 채워주세요.', photoUrls: ['https://picsum.photos/400/300?random=11'], by: 'Manager Lee', at: '2026-03-02T17:50'),
            ChecklistItemEvent(type: 'responded', comment: '추가로 채웠습니다. 확인 부탁드립니다.', photoUrls: ['https://picsum.photos/400/300?random=12', 'https://picsum.photos/400/300?random=13'], by: 'park sung min', at: '2026-03-02T18:15'),
            ChecklistItemEvent(type: 'rejected', comment: '3번 소스통이 아직 부족합니다. 사진 참고해주세요.', photoUrls: ['https://picsum.photos/400/300?random=14'], by: 'Manager Lee', at: '2026-03-02T18:30'),
            ChecklistItemEvent(type: 'responded', comment: '소스통 전부 가득 채웠습니다. 사진 첨부합니다.', photoUrls: ['https://picsum.photos/400/300?random=22', 'https://picsum.photos/400/300?random=23'], by: 'park sung min', at: '2026-03-02T19:10'),
          ],
        ),
      ],
    ),
  ),

  // Store 3: Seoul Station Bakery — 정상 완료 (사진+코멘트 인증)
  Assignment(
    id: 'asgn-past-03',
    store: const Store(id: 'store-003', name: 'Seoul Station Bakery'),
    shift: const ShiftInfo(id: 'shift-003', name: 'Afternoon (14:00-19:00)'),
    position: const PositionInfo(id: 'pos-003', name: 'Baker'),
    status: 'completed',
    workDate: DateTime.now().subtract(const Duration(days: 1)),
    checklistSnapshot: ChecklistSnapshot(
      templateId: 'tmpl-003',
      templateName: 'Baker Afternoon Prep',
      items: const [
        ChecklistItem(index: 0, title: '오븐 예열', verificationType: 'photo', isCompleted: true, completedAt: '2026-03-02T14:10', completedTz: 'KST', completedBy: 'park sung min', photoUrl: 'https://picsum.photos/400/300?random=3', sortOrder: 0),
        ChecklistItem(index: 1, title: '반죽 발효 상태 확인', verificationType: 'photo_comment', isCompleted: true, completedAt: '2026-03-02T14:25', completedTz: 'KST', completedBy: 'park sung min', photoUrl: 'https://picsum.photos/400/300?random=4', comment: '모든 반죽 정상 발효 중, 온도 27도', sortOrder: 1),
        ChecklistItem(index: 2, title: '제빵 재료 재고 확인', verificationType: 'comment', isCompleted: true, completedAt: '2026-03-02T14:35', completedTz: 'KST', completedBy: 'park sung min', comment: '밀가루 5kg 추가 주문 필요, 나머지 재고 충분', sortOrder: 2),
      ],
    ),
  ),

  // ── Past: 2 days ago ───────────────────────────────────────
  Assignment(
    id: 'asgn-past-04',
    store: const Store(id: 'store-002', name: 'Bistro Garden'),
    shift: const ShiftInfo(id: 'shift-001', name: 'Morning (09:00-14:00)'),
    position: const PositionInfo(id: 'pos-004', name: 'Floor Manager'),
    status: 'completed',
    workDate: DateTime.now().subtract(const Duration(days: 2)),
    checklistSnapshot: ChecklistSnapshot(
      templateId: 'tmpl-004',
      templateName: 'Floor Manager Opening',
      items: const [
        ChecklistItem(index: 0, title: '직원 스케줄 확인', verificationType: 'none', isCompleted: true, completedAt: '2026-03-01T08:50', completedTz: 'KST', completedBy: 'park sung min', sortOrder: 0),
        ChecklistItem(index: 1, title: '각 스테이션 인원 배치 확인', verificationType: 'none', isCompleted: true, completedAt: '2026-03-01T08:55', completedTz: 'KST', completedBy: 'park sung min', sortOrder: 1),
        ChecklistItem(
          index: 2, title: '다이닝 구역 청결 점검', verificationType: 'photo', sortOrder: 2,
          isCompleted: true, completedAt: '2026-03-01T12:00', completedTz: 'KST', completedBy: 'park sung min',
          photoUrl: 'https://picsum.photos/400/300?random=5',
          rejectionComment: '테이블 3번 밑에 음식물 잔여물이 있습니다.', rejectedBy: 'Manager Lee', rejectedAt: '2026-03-01T11:00',
          responseComment: '테이블 3번 아래 청소 완료했습니다.', respondedAt: '2026-03-01T12:00', respondedBy: 'park sung min',
          history: [
            ChecklistItemEvent(type: 'completed', comment: null, photoUrls: ['https://picsum.photos/400/300?random=15'], by: 'park sung min', at: '2026-03-01T09:30'),
            ChecklistItemEvent(type: 'rejected', comment: '테이블 3번 밑에 음식물 잔여물이 있습니다.', photoUrls: ['https://picsum.photos/400/300?random=16'], by: 'Manager Lee', at: '2026-03-01T11:00'),
            ChecklistItemEvent(type: 'responded', comment: '테이블 3번 아래 청소 완료했습니다.', photoUrls: ['https://picsum.photos/400/300?random=5'], by: 'park sung min', at: '2026-03-01T12:00'),
          ],
        ),
        ChecklistItem(index: 3, title: '오늘의 메뉴 직원 공유', verificationType: 'none', isCompleted: true, completedAt: '2026-03-01T09:05', completedTz: 'KST', completedBy: 'park sung min', sortOrder: 3),
        ChecklistItem(index: 4, title: '정문 오픈 시간 해제', verificationType: 'none', isCompleted: true, completedAt: '2026-03-01T09:10', completedTz: 'KST', completedBy: 'park sung min', sortOrder: 4),
      ],
    ),
  ),

  // ── Past: 3 days ago ───────────────────────────────────────
  Assignment(
    id: 'asgn-past-05',
    store: const Store(id: 'store-001', name: 'Cafe Bloom'),
    shift: const ShiftInfo(id: 'shift-001', name: 'Morning (09:00-14:00)'),
    position: const PositionInfo(id: 'pos-001', name: 'Barista'),
    status: 'completed',
    workDate: DateTime.now().subtract(const Duration(days: 3)),
    checklistSnapshot: ChecklistSnapshot(
      templateId: 'tmpl-001',
      templateName: 'Barista Opening Checklist',
      items: const [
        ChecklistItem(index: 0, title: '에스프레소 머신 압력 확인', verificationType: 'none', isCompleted: true, completedAt: '2026-02-28T09:10', completedTz: 'KST', completedBy: 'park sung min', sortOrder: 0),
        ChecklistItem(index: 1, title: '우유 스테이션 준비', verificationType: 'comment', isCompleted: true, completedAt: '2026-02-28T09:15', completedTz: 'KST', completedBy: 'park sung min', comment: '유통기한 확인 완료', sortOrder: 1),
        ChecklistItem(index: 2, title: '컵/뚜껑 재고 확인', verificationType: 'none', isCompleted: true, completedAt: '2026-02-28T09:20', completedTz: 'KST', completedBy: 'park sung min', sortOrder: 2),
        ChecklistItem(index: 3, title: '카운터 청소', verificationType: 'photo', isCompleted: true, completedAt: '2026-02-28T09:25', completedTz: 'KST', completedBy: 'park sung min', photoUrl: 'https://picsum.photos/400/300?random=6', sortOrder: 3),
      ],
    ),
  ),

  // ── Past: 5 days ago ───────────────────────────────────────
  Assignment(
    id: 'asgn-past-06',
    store: const Store(id: 'store-003', name: 'Seoul Station Bakery'),
    shift: const ShiftInfo(id: 'shift-003', name: 'Afternoon (14:00-19:00)'),
    position: const PositionInfo(id: 'pos-003', name: 'Baker'),
    status: 'completed',
    workDate: DateTime.now().subtract(const Duration(days: 5)),
    checklistSnapshot: ChecklistSnapshot(
      templateId: 'tmpl-003',
      templateName: 'Baker Afternoon Prep',
      items: const [
        ChecklistItem(index: 0, title: '오븐 예열', verificationType: 'photo', isCompleted: true, completedAt: '2026-02-26T14:10', completedTz: 'KST', completedBy: 'park sung min', photoUrl: 'https://picsum.photos/400/300?random=7', sortOrder: 0),
        ChecklistItem(index: 1, title: '반죽 발효 상태 확인', verificationType: 'photo_comment', isCompleted: true, completedAt: '2026-02-26T14:20', completedTz: 'KST', completedBy: 'park sung min', photoUrl: 'https://picsum.photos/400/300?random=8', comment: '발효 정상, 온도 26도', sortOrder: 1),
        ChecklistItem(index: 2, title: '제빵 재료 재고 확인', verificationType: 'comment', isCompleted: true, completedAt: '2026-02-26T14:30', completedTz: 'KST', completedBy: 'park sung min', comment: '재고 충분', sortOrder: 2),
      ],
    ),
  ),

  // ── Past: 7 days ago ───────────────────────────────────────
  Assignment(
    id: 'asgn-past-07',
    store: const Store(id: 'store-001', name: 'Cafe Bloom'),
    shift: const ShiftInfo(id: 'shift-001', name: 'Morning (09:00-14:00)'),
    position: const PositionInfo(id: 'pos-001', name: 'Barista'),
    status: 'completed',
    workDate: DateTime.now().subtract(const Duration(days: 7)),
    checklistSnapshot: ChecklistSnapshot(
      templateId: 'tmpl-001',
      templateName: 'Barista Opening Checklist',
      items: const [
        ChecklistItem(index: 0, title: '에스프레소 머신 압력 확인', verificationType: 'none', isCompleted: true, completedAt: '2026-02-24T09:10', completedTz: 'KST', completedBy: 'park sung min', sortOrder: 0),
        ChecklistItem(index: 1, title: '우유 스테이션 준비', verificationType: 'none', isCompleted: true, completedAt: '2026-02-24T09:15', completedTz: 'KST', completedBy: 'park sung min', sortOrder: 1),
        ChecklistItem(index: 2, title: '컵/뚜껑 재고 확인', verificationType: 'none', isCompleted: true, completedAt: '2026-02-24T09:20', completedTz: 'KST', completedBy: 'park sung min', sortOrder: 2),
        ChecklistItem(index: 3, title: '카운터 청소', verificationType: 'none', isCompleted: true, completedAt: '2026-02-24T09:25', completedTz: 'KST', completedBy: 'park sung min', sortOrder: 3),
      ],
    ),
  ),
];
