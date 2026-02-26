import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/schedule_shift.dart';
import '../../utils/toast_manager.dart';
import '../../widgets/app_modal.dart';

// ═══════════════════════════════════════════════════════════════
//  Enums & Models
// ═══════════════════════════════════════════════════════════════

enum _ScheduleMode { option1, option2 }

enum _DayApplicationStatus { draft, pending, approved, rejected }

class _ShiftPreset {
  final String id;
  final String name;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Color color;

  const _ShiftPreset({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.color,
  });

  String get timeLabel =>
      '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}'
      ' ~ '
      '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
}

class _DayAvailability {
  final DateTime date;
  bool enabled;
  TimeOfDay startTime;
  TimeOfDay endTime;
  _DayApplicationStatus status;
  String? selectedPresetId; // null = manual

  _DayAvailability({
    required this.date,
    this.enabled = false,
    this.startTime = const TimeOfDay(hour: 9, minute: 0),
    this.endTime = const TimeOfDay(hour: 18, minute: 0),
    this.status = _DayApplicationStatus.draft,
    this.selectedPresetId,
  });
}

class _WorkRecord {
  final DateTime date;
  final String startTime;
  final String endTime;
  final String storeName;
  final String positionName;
  final double hoursWorked;

  const _WorkRecord({
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.storeName,
    required this.positionName,
    required this.hoursWorked,
  });

  String get timeRange => '$startTime ~ $endTime';
}

// ═══════════════════════════════════════════════════════════════
//  Main Screen
// ═══════════════════════════════════════════════════════════════

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});
  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  // ─── Top-level tab ───
  int _topTabIndex = 0;

  // ─── Tab 0: 근무 신청 state ───
  _ScheduleMode _mode = _ScheduleMode.option1;
  late DateTime _selectedDate;
  late DateTime _currentWeekStart;
  List<ScheduleShift> _shifts = [];

  // ─── Tab 1: 근무 내역 state ───
  late DateTime _historyCalendarMonth;
  late DateTime _historySelectedDay;
  late DateTime _historyPayPeriodStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Tab 0
    _selectedDate = today;
    _currentWeekStart = _getMonday(today);
    _loadShifts();

    // Tab 1
    _historyCalendarMonth = DateTime(now.year, now.month, 1);
    _historySelectedDay = today;
    _historyPayPeriodStart = _calcPayPeriodStart(today);
  }

  // ─── Shared helpers ───

  DateTime _getMonday(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static const _weekdayFull = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

  // ─── Tab 0: Option 1 methods ───

  String _dateKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _loadShifts() {
    final key = _dateKey(_selectedDate);
    setState(() {
      _shifts = (_mockShifts[key] ?? [])
          .map((s) => ScheduleShift(
                id: s.id, date: s.date, startTime: s.startTime, endTime: s.endTime,
                shiftName: s.shiftName, storeName: s.storeName, positionName: s.positionName,
                totalSlots: s.totalSlots, filledSlots: s.filledSlots, status: s.status,
              ))
          .toList();
    });
  }

  void _onDaySelected(DateTime date) {
    setState(() => _selectedDate = date);
    _loadShifts();
  }

  void _onWeekChanged(int delta) {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(Duration(days: delta));
      if (_selectedDate.isBefore(_currentWeekStart) ||
          _selectedDate.isAfter(_currentWeekStart.add(const Duration(days: 6)))) {
        _selectedDate = _currentWeekStart;
      }
    });
    _loadShifts();
  }

  Future<void> _applyForShift(String shiftId) async {
    final result = await AppModal.show(
      context,
      title: '근무 신청',
      message: '이 근무를 신청하시겠습니까?\n관리자 승인 후 확정됩니다.',
      type: ModalType.confirm,
      confirmText: '신청',
      cancelText: '취소',
    );
    if (result == true && mounted) {
      setState(() {
        _shifts = _shifts.map((s) {
          if (s.id == shiftId) return s.copyWith(status: ShiftApplicationStatus.pending);
          return s;
        }).toList();
      });
      final key = _dateKey(_selectedDate);
      _mockShifts[key] = _shifts;
      ToastManager().info(context, '근무 신청이 완료되었습니다.');
    }
  }

  bool get _isPastDate {
    final today = DateTime.now();
    return _selectedDate.isBefore(DateTime(today.year, today.month, today.day));
  }

  String _getDateHeader() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_selectedDate == today) return '오늘';
    final tomorrow = today.add(const Duration(days: 1));
    if (_selectedDate == tomorrow) return '내일';
    return '${_selectedDate.month}월 ${_selectedDate.day}일 ${_weekdayFull[_selectedDate.weekday - 1]}';
  }

  // ─── Tab 1: Pay Period helpers ───

  static final DateTime _payPeriodAnchor = DateTime(2026, 1, 5); // Monday

  static DateTime _calcPayPeriodStart(DateTime date) {
    final diff = date.difference(_payPeriodAnchor).inDays;
    final periodsElapsed = diff < 0 ? (diff / 14).floor() : diff ~/ 14;
    return _payPeriodAnchor.add(Duration(days: periodsElapsed * 14));
  }

  static DateTime _calcPayPeriodEnd(DateTime start) {
    return start.add(const Duration(days: 13));
  }

  List<_WorkRecord> get _payPeriodRecords {
    final start = _historyPayPeriodStart;
    final end = _calcPayPeriodEnd(start);
    return _mockWorkRecords.where((r) =>
        !r.date.isBefore(start) && !r.date.isAfter(end)).toList();
  }

  int get _payPeriodWorkDays {
    return _payPeriodRecords.map((r) => _dateKey(r.date)).toSet().length;
  }

  double get _payPeriodWorkHours {
    return _payPeriodRecords.fold(0.0, (sum, r) => sum + r.hoursWorked);
  }

  void _onPayPeriodChanged(int delta) {
    setState(() {
      _historyPayPeriodStart = _historyPayPeriodStart.add(Duration(days: delta));
    });
  }

  void _onHistoryMonthChanged(int delta) {
    setState(() {
      _historyCalendarMonth = DateTime(
        _historyCalendarMonth.year,
        _historyCalendarMonth.month + delta,
        1,
      );
      if (_historySelectedDay.month != _historyCalendarMonth.month ||
          _historySelectedDay.year != _historyCalendarMonth.year) {
        _historySelectedDay = _historyCalendarMonth;
      }
    });
  }

  void _onHistoryDaySelected(DateTime day) {
    setState(() {
      _historySelectedDay = day;
      _historyPayPeriodStart = _calcPayPeriodStart(day);
    });
  }

  List<_WorkRecord> _recordsForDay(DateTime day) {
    return _mockWorkRecords.where((r) => _isSameDay(r.date, day)).toList();
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top-level tab bar
        _TopTabBar(
          selectedIndex: _topTabIndex,
          onTabChanged: (i) => setState(() => _topTabIndex = i),
        ),

        // Tab 0: 근무 신청
        if (_topTabIndex == 0) ...[
          _ModeSwitcherBar(
            currentMode: _mode,
            onModeChanged: (mode) => setState(() => _mode = mode),
          ),
          if (_mode == _ScheduleMode.option1) ...[
            _WeekStrip(
              currentWeekStart: _currentWeekStart,
              selectedDate: _selectedDate,
              onDaySelected: _onDaySelected,
              onWeekChanged: _onWeekChanged,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Text(_getDateHeader(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                  const SizedBox(width: 8),
                  Text('${_shifts.length}건',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                ],
              ),
            ),
            Expanded(
              child: _shifts.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemCount: _shifts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _ShiftCard(
                        shift: _shifts[i],
                        isPastDate: _isPastDate,
                        onApply: () => _applyForShift(_shifts[i].id),
                      ),
                    ),
            ),
          ],
          if (_mode == _ScheduleMode.option2)
            Expanded(child: _AvailabilityView(weekStart: _currentWeekStart)),
        ],

        // Tab 1: 근무 내역
        if (_topTabIndex == 1)
          Expanded(
            child: _WorkHistoryView(
              allRecords: _mockWorkRecords,
              payPeriodStart: _historyPayPeriodStart,
              calendarMonth: _historyCalendarMonth,
              selectedDay: _historySelectedDay,
              dayRecords: _recordsForDay(_historySelectedDay),
              payPeriodWorkDays: _payPeriodWorkDays,
              payPeriodWorkHours: _payPeriodWorkHours,
              onPrevPayPeriod: () => _onPayPeriodChanged(-14),
              onNextPayPeriod: () => _onPayPeriodChanged(14),
              onMonthChanged: _onHistoryMonthChanged,
              onDaySelected: _onHistoryDaySelected,
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_rounded, size: 56, color: AppColors.border),
          SizedBox(height: 16),
          Text(
            '해당 날짜에 신청 가능한\n근무가 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.textMuted, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Mock Data
  // ═══════════════════════════════════════════════════════════════

  static DateTime _day(int offset) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + offset);
  }

  static String _key(int offset) {
    final d = _day(offset);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  // ─── Option 1 mock shifts ───
  static final Map<String, List<ScheduleShift>> _mockShifts = {
    _key(-2): [
      ScheduleShift(id: 's1', date: _day(-2), startTime: '09:00', endTime: '14:00',
          shiftName: '오전', storeName: 'Cafe Bloom 강남점', positionName: '바리스타',
          totalSlots: 3, filledSlots: 2, status: ShiftApplicationStatus.approved),
    ],
    _key(-1): [
      ScheduleShift(id: 's2', date: _day(-1), startTime: '09:00', endTime: '14:00',
          shiftName: '오전', storeName: 'Cafe Bloom 강남점', positionName: '바리스타',
          totalSlots: 3, filledSlots: 3, status: ShiftApplicationStatus.approved),
      ScheduleShift(id: 's3', date: _day(-1), startTime: '14:00', endTime: '19:00',
          shiftName: '오후', storeName: 'Bistro Garden 홍대점', positionName: '홀 서빙',
          totalSlots: 2, filledSlots: 2, status: ShiftApplicationStatus.rejected),
    ],
    _key(0): [
      ScheduleShift(id: 's4', date: _day(0), startTime: '09:00', endTime: '14:00',
          shiftName: '오전', storeName: 'Cafe Bloom 강남점', positionName: '바리스타', totalSlots: 3, filledSlots: 1),
      ScheduleShift(id: 's5', date: _day(0), startTime: '14:00', endTime: '19:00',
          shiftName: '오후', storeName: 'Seoul Station Bakery', positionName: '제빵사', totalSlots: 2, filledSlots: 0),
      ScheduleShift(id: 's6', date: _day(0), startTime: '18:00', endTime: '23:00',
          shiftName: '야간', storeName: 'Bistro Garden 홍대점', positionName: '홀 서빙',
          totalSlots: 4, filledSlots: 2, status: ShiftApplicationStatus.pending),
    ],
    _key(1): [
      ScheduleShift(id: 's7', date: _day(1), startTime: '09:00', endTime: '14:00',
          shiftName: '오전', storeName: 'Cafe Bloom 강남점', positionName: '바리스타', totalSlots: 3, filledSlots: 0),
      ScheduleShift(id: 's8', date: _day(1), startTime: '14:00', endTime: '19:00',
          shiftName: '오후', storeName: 'Bistro Garden 홍대점', positionName: '홀 서빙', totalSlots: 2, filledSlots: 1),
    ],
    _key(2): [
      ScheduleShift(id: 's9', date: _day(2), startTime: '18:00', endTime: '23:00',
          shiftName: '야간', storeName: 'Seoul Station Bakery', positionName: '제빵사', totalSlots: 2, filledSlots: 1),
    ],
    _key(4): [
      ScheduleShift(id: 's10', date: _day(4), startTime: '09:00', endTime: '14:00',
          shiftName: '오전', storeName: 'Cafe Bloom 강남점', positionName: '바리스타', totalSlots: 4, filledSlots: 0),
    ],
  };

  // ─── Work history mock records ───
  static final List<_WorkRecord> _mockWorkRecords = [
    _WorkRecord(date: _day(-1), startTime: '09:00', endTime: '14:00', storeName: 'Cafe Bloom 강남점', positionName: '바리스타', hoursWorked: 5),
    _WorkRecord(date: _day(-1), startTime: '15:00', endTime: '20:00', storeName: 'Bistro Garden 홍대점', positionName: '홀 서빙', hoursWorked: 5),
    _WorkRecord(date: _day(-3), startTime: '09:00', endTime: '17:00', storeName: 'Seoul Station Bakery', positionName: '제빵사', hoursWorked: 8),
    _WorkRecord(date: _day(-5), startTime: '14:00', endTime: '22:00', storeName: 'Cafe Bloom 강남점', positionName: '바리스타', hoursWorked: 8),
    _WorkRecord(date: _day(-7), startTime: '10:00', endTime: '15:00', storeName: 'Bistro Garden 홍대점', positionName: '홀 서빙', hoursWorked: 5),
    _WorkRecord(date: _day(-8), startTime: '09:00', endTime: '13:00', storeName: 'Seoul Station Bakery', positionName: '제빵사', hoursWorked: 4),
    _WorkRecord(date: _day(-10), startTime: '13:00', endTime: '21:00', storeName: 'Cafe Bloom 강남점', positionName: '바리스타', hoursWorked: 8),
    _WorkRecord(date: _day(-12), startTime: '09:00', endTime: '18:00', storeName: 'Bistro Garden 홍대점', positionName: '홀 서빙', hoursWorked: 9),
    _WorkRecord(date: _day(-14), startTime: '09:00', endTime: '14:00', storeName: 'Seoul Station Bakery', positionName: '제빵사', hoursWorked: 5),
    _WorkRecord(date: _day(-14), startTime: '15:00', endTime: '20:00', storeName: 'Cafe Bloom 강남점', positionName: '바리스타', hoursWorked: 5),
    _WorkRecord(date: _day(-16), startTime: '10:00', endTime: '18:00', storeName: 'Bistro Garden 홍대점', positionName: '홀 서빙', hoursWorked: 8),
    _WorkRecord(date: _day(-18), startTime: '09:00', endTime: '17:00', storeName: 'Seoul Station Bakery', positionName: '제빵사', hoursWorked: 8),
    _WorkRecord(date: _day(-22), startTime: '09:00', endTime: '14:00', storeName: 'Cafe Bloom 강남점', positionName: '바리스타', hoursWorked: 5),
    _WorkRecord(date: _day(-24), startTime: '14:00', endTime: '22:00', storeName: 'Bistro Garden 홍대점', positionName: '홀 서빙', hoursWorked: 8),
    _WorkRecord(date: _day(-26), startTime: '09:00', endTime: '17:00', storeName: 'Seoul Station Bakery', positionName: '제빵사', hoursWorked: 8),
    _WorkRecord(date: _day(-28), startTime: '10:00', endTime: '15:00', storeName: 'Cafe Bloom 강남점', positionName: '바리스타', hoursWorked: 5),
    _WorkRecord(date: _day(-30), startTime: '09:00', endTime: '18:00', storeName: 'Bistro Garden 홍대점', positionName: '홀 서빙', hoursWorked: 9),
    _WorkRecord(date: _day(-32), startTime: '09:00', endTime: '13:00', storeName: 'Seoul Station Bakery', positionName: '제빵사', hoursWorked: 4),
  ];
}

// ═══════════════════════════════════════════════════════════════
//  Top Tab Bar
// ═══════════════════════════════════════════════════════════════

class _TopTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  const _TopTabBar({required this.selectedIndex, required this.onTabChanged});

  static const _labels = ['근무 신청', '근무 내역'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final active = selectedIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Text(
                      _labels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? AppColors.accent : AppColors.textMuted,
                      ),
                    ),
                  ),
                  Container(
                    height: 2,
                    color: active ? AppColors.accent : Colors.transparent,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Mode Switcher Bar (1안/2안)
// ═══════════════════════════════════════════════════════════════

class _ModeSwitcherBar extends StatelessWidget {
  final _ScheduleMode currentMode;
  final ValueChanged<_ScheduleMode> onModeChanged;

  const _ModeSwitcherBar({required this.currentMode, required this.onModeChanged});

  String get _label => currentMode == _ScheduleMode.option1 ? '1안: 근무 신청' : '2안: 근무 희망 제출';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () => _showMenu(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context) async {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);
    final result = await showMenu<_ScheduleMode>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + box.size.width - 200, offset.dy + box.size.height,
        offset.dx + box.size.width, 0,
      ),
      items: [
        PopupMenuItem(value: _ScheduleMode.option1, child: Row(children: [
          Icon(currentMode == _ScheduleMode.option1 ? Icons.check_circle : Icons.circle_outlined,
              size: 18, color: currentMode == _ScheduleMode.option1 ? AppColors.accent : AppColors.textMuted),
          const SizedBox(width: 10),
          const Text('1안: 근무 신청', style: TextStyle(fontSize: 14)),
        ])),
        PopupMenuItem(value: _ScheduleMode.option2, child: Row(children: [
          Icon(currentMode == _ScheduleMode.option2 ? Icons.check_circle : Icons.circle_outlined,
              size: 18, color: currentMode == _ScheduleMode.option2 ? AppColors.accent : AppColors.textMuted),
          const SizedBox(width: 10),
          const Text('2안: 근무 희망 제출', style: TextStyle(fontSize: 14)),
        ])),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
    );
    if (result != null) onModeChanged(result);
  }
}

// ═══════════════════════════════════════════════════════════════
//  Tab 1: Work History View
// ═══════════════════════════════════════════════════════════════

class _WorkHistoryView extends StatelessWidget {
  final List<_WorkRecord> allRecords;
  final DateTime payPeriodStart;
  final DateTime calendarMonth;
  final DateTime selectedDay;
  final List<_WorkRecord> dayRecords;
  final int payPeriodWorkDays;
  final double payPeriodWorkHours;
  final VoidCallback onPrevPayPeriod;
  final VoidCallback onNextPayPeriod;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;

  const _WorkHistoryView({
    required this.allRecords,
    required this.payPeriodStart,
    required this.calendarMonth,
    required this.selectedDay,
    required this.dayRecords,
    required this.payPeriodWorkDays,
    required this.payPeriodWorkHours,
    required this.onPrevPayPeriod,
    required this.onNextPayPeriod,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PayPeriodStatsCard(
          payPeriodStart: payPeriodStart,
          workDays: payPeriodWorkDays,
          workHours: payPeriodWorkHours,
          onPrev: onPrevPayPeriod,
          onNext: onNextPayPeriod,
        ),
        _MonthCalendarGrid(
          month: calendarMonth,
          selectedDay: selectedDay,
          recordDates: allRecords.map((r) => r.date).toSet(),
          onMonthChanged: onMonthChanged,
          onDaySelected: onDaySelected,
        ),
        Expanded(
          child: _DayWorkRecordList(
            selectedDay: selectedDay,
            records: dayRecords,
          ),
        ),
      ],
    );
  }
}

// ─── Pay Period Stats Card ────────────────────────────────────

class _PayPeriodStatsCard extends StatelessWidget {
  final DateTime payPeriodStart;
  final int workDays;
  final double workHours;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _PayPeriodStatsCard({
    required this.payPeriodStart,
    required this.workDays,
    required this.workHours,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final end = payPeriodStart.add(const Duration(days: 13));
    final label = '${payPeriodStart.month}/${payPeriodStart.day} ~ ${end.month}/${end.day}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Pay period navigation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  onPressed: onPrev,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  color: AppColors.textSecondary,
                ),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  onPressed: onNext,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(child: _StatColumn(label: '근무일', value: '$workDays일')),
                Container(width: 1, height: 36, color: AppColors.border),
                Expanded(child: _StatColumn(label: '근무시간', value: '${workHours % 1 == 0 ? workHours.toInt() : workHours.toStringAsFixed(1)}h')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accent)),
      ],
    );
  }
}

// ─── Month Calendar Grid ────────────────────────────────────

class _MonthCalendarGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDay;
  final Set<DateTime> recordDates;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;

  const _MonthCalendarGrid({
    required this.month,
    required this.selectedDay,
    required this.recordDates,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  static const _weekdayShort = ['월', '화', '수', '목', '금', '토', '일'];

  bool _hasWork(DateTime date) {
    return recordDates.any((d) => d.year == date.year && d.month == date.month && d.day == date.day);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final lastOfMonth = DateTime(month.year, month.month + 1, 0);
    final startOffset = firstOfMonth.weekday - 1; // Mon=0
    final totalCells = startOffset + lastOfMonth.day;
    final numWeeks = (totalCells / 7).ceil();
    final monthLabel = '${month.year}년 ${month.month}월';

    return Column(
      children: [
        // Month navigation header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                onPressed: () => onMonthChanged(-1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(monthLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                onPressed: () => onMonthChanged(1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        // Weekday header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: List.generate(7, (i) {
              final isWeekend = i >= 5;
              return Expanded(
                child: Center(
                  child: Text(
                    _weekdayShort[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isWeekend ? AppColors.danger.withValues(alpha: 0.6) : AppColors.textMuted,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
        // Day grid
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Column(
            children: List.generate(numWeeks, (row) {
              return Row(
                children: List.generate(7, (col) {
                  final dayIndex = row * 7 + col - startOffset;
                  final cellDate = DateTime(month.year, month.month, dayIndex + 1);
                  final isCurrentMonth = cellDate.month == month.month && cellDate.year == month.year;
                  final isSelected = isCurrentMonth &&
                      cellDate.day == selectedDay.day && cellDate.month == selectedDay.month && cellDate.year == selectedDay.year;
                  final isToday = cellDate.year == today.year && cellDate.month == today.month && cellDate.day == today.day;
                  final hasWork = isCurrentMonth && _hasWork(cellDate);

                  return Expanded(
                    child: GestureDetector(
                      onTap: isCurrentMonth ? () => onDaySelected(cellDate) : null,
                      child: SizedBox(
                        height: 46,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.accent : Colors.transparent,
                                shape: BoxShape.circle,
                                border: isToday && !isSelected
                                    ? Border.all(color: AppColors.accent, width: 1.5)
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${cellDate.day}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w400,
                                  color: isSelected
                                      ? Colors.white
                                      : isToday
                                          ? AppColors.accent
                                          : isCurrentMonth
                                              ? AppColors.text
                                              : AppColors.textMuted.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: hasWork && !isSelected ? AppColors.accent : Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ─── Day Work Record List ────────────────────────────────────

class _DayWorkRecordList extends StatelessWidget {
  final DateTime selectedDay;
  final List<_WorkRecord> records;

  const _DayWorkRecordList({required this.selectedDay, required this.records});

  static const _weekdayFull = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

  @override
  Widget build(BuildContext context) {
    final dayLabel = '${selectedDay.month}월 ${selectedDay.day}일 ${_weekdayFull[selectedDay.weekday - 1]}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Text(dayLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(width: 8),
              Text('${records.length}건', style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
            ],
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.work_off_rounded, size: 40, color: AppColors.border),
                      SizedBox(height: 12),
                      Text('이 날은 근무 기록이 없습니다.',
                          style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _WorkRecordCard(record: records[i]),
                ),
        ),
      ],
    );
  }
}

class _WorkRecordCard extends StatelessWidget {
  final _WorkRecord record;

  const _WorkRecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final hoursLabel = record.hoursWorked % 1 == 0
        ? '${record.hoursWorked.toInt()}h'
        : '${record.hoursWorked.toStringAsFixed(1)}h';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Left accent bar
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.storeName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(record.positionName,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent)),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.schedule_rounded, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text(record.timeRange,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Hours
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(hoursLabel,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.accent)),
              const Text('근무', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Option 2: Availability View (with Shift Presets)
// ═══════════════════════════════════════════════════════════════

// Mock brand presets — in production, fetched from admin settings per brand
const _mockBrandPresets = <_ShiftPreset>[
  _ShiftPreset(id: 'morning', name: 'Morning', startTime: TimeOfDay(hour: 9, minute: 0), endTime: TimeOfDay(hour: 14, minute: 0), color: Color(0xFFF39C12)),
  _ShiftPreset(id: 'swing', name: 'Swing', startTime: TimeOfDay(hour: 14, minute: 0), endTime: TimeOfDay(hour: 19, minute: 0), color: Color(0xFF6C5CE7)),
  _ShiftPreset(id: 'close', name: 'Close', startTime: TimeOfDay(hour: 19, minute: 0), endTime: TimeOfDay(hour: 23, minute: 0), color: Color(0xFF00B894)),
];

class _AvailabilityView extends StatefulWidget {
  final DateTime weekStart;
  const _AvailabilityView({required this.weekStart});
  @override
  State<_AvailabilityView> createState() => _AvailabilityViewState();
}

class _AvailabilityViewState extends State<_AvailabilityView> {
  late List<_DayAvailability> _days;

  static const _weekdayFull = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

  @override
  void initState() {
    super.initState();
    _initDays();
  }

  @override
  void didUpdateWidget(covariant _AvailabilityView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weekStart != widget.weekStart) _initDays();
  }

  void _initDays() {
    _days = List.generate(7, (i) {
      final date = widget.weekStart.add(Duration(days: i));
      if (i == 3) {
        return _DayAvailability(date: date, enabled: true,
            startTime: const TimeOfDay(hour: 14, minute: 0), endTime: const TimeOfDay(hour: 19, minute: 0),
            selectedPresetId: 'swing', status: _DayApplicationStatus.pending);
      }
      if (i == 4) {
        return _DayAvailability(date: date, enabled: true,
            startTime: const TimeOfDay(hour: 9, minute: 0), endTime: const TimeOfDay(hour: 14, minute: 0),
            selectedPresetId: 'morning', status: _DayApplicationStatus.approved);
      }
      if (i <= 2) {
        return _DayAvailability(date: date, enabled: true, selectedPresetId: 'morning');
      }
      return _DayAvailability(date: date);
    });
  }

  bool get _hasEnabledDraft => _days.any((d) => d.enabled && d.status == _DayApplicationStatus.draft);
  bool get _hasPending => _days.any((d) => d.status == _DayApplicationStatus.pending);

  void _toggleDay(int index) {
    if (_days[index].status != _DayApplicationStatus.draft) return;
    setState(() {
      _days[index].enabled = !_days[index].enabled;
      if (!_days[index].enabled) {
        _days[index].selectedPresetId = null;
      }
    });
  }

  void _selectPreset(int index, String? presetId) {
    if (_days[index].status != _DayApplicationStatus.draft) return;
    setState(() {
      _days[index].selectedPresetId = presetId;
      if (presetId != null) {
        final preset = _mockBrandPresets.firstWhere((p) => p.id == presetId);
        _days[index].startTime = preset.startTime;
        _days[index].endTime = preset.endTime;
      }
    });
  }

  void _updateStartTime(int index, TimeOfDay time) {
    setState(() {
      _days[index].startTime = time;
      _days[index].selectedPresetId = null; // switch to manual
    });
  }

  void _updateEndTime(int index, TimeOfDay time) {
    setState(() {
      _days[index].endTime = time;
      _days[index].selectedPresetId = null; // switch to manual
    });
  }

  void _copyToAll() {
    final source = _days.cast<_DayAvailability?>().firstWhere(
        (d) => d!.enabled && d.status == _DayApplicationStatus.draft, orElse: () => null);
    if (source == null) { ToastManager().warning(context, '복사할 날짜를 먼저 선택해주세요.'); return; }
    setState(() {
      for (final d in _days) {
        if (d.enabled && d.status == _DayApplicationStatus.draft && d != source) {
          d.selectedPresetId = source.selectedPresetId;
          d.startTime = source.startTime;
          d.endTime = source.endTime;
        }
      }
    });
    ToastManager().info(context, '시간이 복사되었습니다.');
  }

  Future<void> _submitAll() async {
    final enabledDraftDays = _days.where((d) => d.enabled && d.status == _DayApplicationStatus.draft).toList();
    if (enabledDraftDays.isEmpty) { ToastManager().warning(context, '근무 희망 날짜를 선택해주세요.'); return; }
    final result = await AppModal.show(context,
        title: '근무 희망 제출',
        message: '${enabledDraftDays.length}일간의 근무 희망을 제출하시겠습니까?\n관리자 승인 후 확정됩니다.',
        type: ModalType.confirm, confirmText: '제출', cancelText: '취소');
    if (result == true && mounted) {
      setState(() { for (final d in enabledDraftDays) { d.status = _DayApplicationStatus.pending; } });
      ToastManager().success(context, '근무 희망이 제출되었습니다.');
    }
  }

  void _resetPending() {
    setState(() { for (final d in _days) { if (d.status == _DayApplicationStatus.pending) d.status = _DayApplicationStatus.draft; } });
    ToastManager().info(context, '수정 모드로 전환되었습니다.');
  }

  String _formatWeekRange() {
    final end = widget.weekStart.add(const Duration(days: 6));
    return '${widget.weekStart.month}월 ${widget.weekStart.day}일 ~ ${end.month}월 ${end.day}일';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Week range header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(children: [
            const Icon(Icons.date_range_rounded, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(_formatWeekRange(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
          ]),
        ),
        // Preset legend + copy bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
          child: Row(children: [
            ..._mockBrandPresets.map((p) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: p.color)),
                const SizedBox(width: 4),
                Text(p.name, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ]),
            )),
            const Spacer(),
            if (_hasEnabledDraft)
              TextButton.icon(
                onPressed: _copyToAll,
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('복사'),
                style: TextButton.styleFrom(foregroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        // Day list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _AvailabilityDayRow(
              day: _days[i],
              weekdayLabel: _weekdayFull[i],
              presets: _mockBrandPresets,
              onToggle: () => _toggleDay(i),
              onPresetSelected: (pid) => _selectPreset(i, pid),
              onStartChanged: (t) => _updateStartTime(i, t),
              onEndChanged: (t) => _updateEndTime(i, t),
            ),
          ),
        ),
        // Submit / Reset button
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(color: AppColors.white, border: Border(top: BorderSide(color: AppColors.border, width: 0.5))),
          child: SizedBox(
            width: double.infinity,
            child: _hasEnabledDraft
                ? ElevatedButton(onPressed: _submitAll,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white,
                        elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    child: const Text('신청하기'))
                : _hasPending
                    ? OutlinedButton(onPressed: _resetPending,
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent,
                            side: const BorderSide(color: AppColors.accent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        child: const Text('수정하기'))
                    : ElevatedButton(onPressed: null,
                        style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        child: const Text('제출 완료')),
          ),
        ),
      ],
    );
  }
}

// ─── Availability Day Row (with Preset Chips) ────────────────

class _AvailabilityDayRow extends StatelessWidget {
  final _DayAvailability day;
  final String weekdayLabel;
  final List<_ShiftPreset> presets;
  final VoidCallback onToggle;
  final ValueChanged<String?> onPresetSelected;
  final ValueChanged<TimeOfDay> onStartChanged;
  final ValueChanged<TimeOfDay> onEndChanged;

  const _AvailabilityDayRow({
    required this.day, required this.weekdayLabel, required this.presets,
    required this.onToggle, required this.onPresetSelected,
    required this.onStartChanged, required this.onEndChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDraft = day.status == _DayApplicationStatus.draft;
    final isDisabled = !day.enabled && isDraft;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDisabled ? const Color(0xFFFAF9FA) : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: day.enabled && isDraft ? AppColors.accent.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Switch + weekday + status/time
          Row(children: [
            SizedBox(width: 44, height: 28, child: Switch(
              value: day.enabled, onChanged: isDraft ? (_) => onToggle() : null,
              activeThumbColor: AppColors.accent, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(weekdayLabel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: isDisabled ? AppColors.textMuted : AppColors.text)),
              const SizedBox(height: 2),
              Text('${day.date.month}월 ${day.date.day}일',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ]),
            const Spacer(),
            _buildStatusOrTime(context),
          ]),
          // Bottom row: Preset chips (only for enabled draft days)
          if (day.enabled && isDraft) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _buildPresetChips(context),
            ),
            // Manual time pickers (when manual mode selected)
            if (day.selectedPresetId == null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  _TimeChip(time: day.startTime, onTap: () => _pickTime(context, day.startTime, onStartChanged)),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('~', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500))),
                  _TimeChip(time: day.endTime, onTap: () => _pickTime(context, day.endTime, onEndChanged)),
                  const Spacer(),
                  const Text('직접 설정', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ]),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusOrTime(BuildContext context) {
    switch (day.status) {
      case _DayApplicationStatus.pending:
        return _statusBadge('대기중', AppColors.warning, AppColors.warningBg);
      case _DayApplicationStatus.approved:
        return _statusBadge('승인됨', AppColors.success, AppColors.successBg);
      case _DayApplicationStatus.rejected:
        return _statusBadge('거절됨', AppColors.danger, AppColors.dangerBg);
      case _DayApplicationStatus.draft:
        if (!day.enabled) return const Text('휴무', style: TextStyle(fontSize: 13, color: AppColors.textMuted));
        // Show selected time summary
        final startLabel = '${day.startTime.hour.toString().padLeft(2, '0')}:${day.startTime.minute.toString().padLeft(2, '0')}';
        final endLabel = '${day.endTime.hour.toString().padLeft(2, '0')}:${day.endTime.minute.toString().padLeft(2, '0')}';
        return Text('$startLabel ~ $endLabel',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent));
    }
  }

  Widget _buildPresetChips(BuildContext context) {
    final isManual = day.selectedPresetId == null;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Preset chips
        ...presets.map((preset) {
          final isSelected = day.selectedPresetId == preset.id;
          return GestureDetector(
            onTap: () => onPresetSelected(preset.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? preset.color.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? preset.color : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: preset.color)),
                const SizedBox(width: 6),
                Text(preset.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: isSelected ? preset.color : AppColors.textSecondary)),
                const SizedBox(width: 4),
                Text(preset.timeLabel, style: TextStyle(fontSize: 11,
                    color: isSelected ? preset.color.withValues(alpha: 0.7) : AppColors.textMuted)),
              ]),
            ),
          );
        }),
        // Manual chip
        GestureDetector(
          onTap: () => onPresetSelected(null),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isManual ? AppColors.accentBg : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isManual ? AppColors.accent : AppColors.border,
                width: isManual ? 1.5 : 1,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.edit_rounded, size: 13,
                  color: isManual ? AppColors.accent : AppColors.textMuted),
              const SizedBox(width: 4),
              Text('직접 입력', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: isManual ? AppColors.accent : AppColors.textSecondary)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  Future<void> _pickTime(BuildContext context, TimeOfDay initial, ValueChanged<TimeOfDay> onChanged) async {
    final picked = await showTimePicker(context: context, initialTime: initial,
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!));
    if (picked != null) onChanged(picked);
  }
}

// ─── Time Chip ────────────────────────────────────

class _TimeChip extends StatelessWidget {
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimeChip({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Option 1 sub-widgets
// ═══════════════════════════════════════════════════════════════

// ─── Week Strip ────────────────────────────────────

class _WeekStrip extends StatelessWidget {
  final DateTime currentWeekStart;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<int> onWeekChanged;

  const _WeekStrip({
    required this.currentWeekStart, required this.selectedDate,
    required this.onDaySelected, required this.onWeekChanged,
  });

  static const _weekdayShort = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final midWeek = currentWeekStart.add(const Duration(days: 3));
    final monthLabel = '${midWeek.year}년 ${midWeek.month}월';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(icon: const Icon(Icons.chevron_left_rounded, size: 22),
                onPressed: () => onWeekChanged(-7), padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36), color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(monthLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.chevron_right_rounded, size: 22),
                onPressed: () => onWeekChanged(7), padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36), color: AppColors.textSecondary),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: List.generate(7, (i) {
              final date = currentWeekStart.add(Duration(days: i));
              final isSelected = date == selectedDate;
              final isToday = date == today;
              final isWeekend = i >= 5;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onDaySelected(date),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_weekdayShort[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                        color: isWeekend ? AppColors.danger.withValues(alpha: 0.6) : AppColors.textMuted)),
                    const SizedBox(height: 6),
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: isSelected ? AppColors.accent : Colors.transparent, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text('${date.day}', style: TextStyle(fontSize: 15,
                          fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : isToday ? AppColors.accent : AppColors.text)),
                    ),
                    const SizedBox(height: 4),
                    Container(width: 5, height: 5,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: isToday ? AppColors.accent : Colors.transparent)),
                  ]),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }
}

// ─── Shift Card ────────────────────────────────────

class _ShiftCard extends StatelessWidget {
  final ScheduleShift shift;
  final bool isPastDate;
  final VoidCallback onApply;

  const _ShiftCard({required this.shift, required this.isPastDate, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(6)),
            child: Text(shift.shiftName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent)),
          ),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(shift.timeRange, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ]),
        ]),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(shift.storeName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(shift.positionName, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          if (shift.status == ShiftApplicationStatus.available && !shift.isFull)
            Padding(padding: const EdgeInsets.only(top: 4),
                child: Text('잔여 ${shift.availableSlots}자리', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                    color: shift.availableSlots <= 1 ? AppColors.danger : AppColors.textMuted))),
        ])),
        const SizedBox(width: 12),
        _buildStatusWidget(),
      ]),
    );
  }

  Widget _buildStatusWidget() {
    if (isPastDate) return _statusBadge();
    switch (shift.status) {
      case ShiftApplicationStatus.available:
        if (shift.isFull) return _badge('마감', AppColors.textMuted, const Color(0xFFF3F4F6));
        return SizedBox(height: 36, child: ElevatedButton(onPressed: onApply,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white,
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            child: const Text('신청')));
      case ShiftApplicationStatus.pending:
      case ShiftApplicationStatus.approved:
      case ShiftApplicationStatus.rejected:
        return _statusBadge();
    }
  }

  Widget _statusBadge() {
    switch (shift.status) {
      case ShiftApplicationStatus.available: return const SizedBox.shrink();
      case ShiftApplicationStatus.pending: return _badge('대기중', AppColors.warning, AppColors.warningBg);
      case ShiftApplicationStatus.approved: return _badge('승인됨', AppColors.success, AppColors.successBg);
      case ShiftApplicationStatus.rejected: return _badge('거절됨', AppColors.danger, AppColors.dangerBg);
    }
  }

  Widget _badge(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}
