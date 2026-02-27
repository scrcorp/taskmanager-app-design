import 'dart:async';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/toast_manager.dart';

// ═══════════════════════════════════════════════════════════════
//  Enums & Models
// ═══════════════════════════════════════════════════════════════

enum _ClockStatus { notClockedIn, clockedIn, clockedOut }

enum _ClockAction { clockIn, clockOut }

class _ClockRecord {
  final String id;
  final DateTime date;
  final DateTime clockInTime;
  final DateTime? clockOutTime;
  final String storeName;
  final String positionName;

  const _ClockRecord({
    required this.id,
    required this.date,
    required this.clockInTime,
    this.clockOutTime,
    required this.storeName,
    required this.positionName,
  });

  Duration get workedDuration {
    final end = clockOutTime ?? DateTime.now();
    return end.difference(clockInTime);
  }

  String get clockInLabel =>
      '${clockInTime.hour.toString().padLeft(2, '0')}:${clockInTime.minute.toString().padLeft(2, '0')}';

  String get clockOutLabel => clockOutTime != null
      ? '${clockOutTime!.hour.toString().padLeft(2, '0')}:${clockOutTime!.minute.toString().padLeft(2, '0')}'
      : '--:--';

  String get durationLabel {
    final d = workedDuration;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }
}

// ═══════════════════════════════════════════════════════════════
//  Main Screen
// ═══════════════════════════════════════════════════════════════

class ClockScreen extends ConsumerStatefulWidget {
  const ClockScreen({super.key});
  @override
  ConsumerState<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends ConsumerState<ClockScreen> {
  _ClockStatus _status = _ClockStatus.notClockedIn;
  DateTime? _todayClockIn;
  DateTime? _todayClockOut;
  Timer? _timer;

  static const _weekdayShort = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_status == _ClockStatus.clockedIn && mounted) {
        setState(() {});
      }
    });
  }

  Duration get _todayWorkedDuration {
    if (_todayClockIn == null) return Duration.zero;
    final end = _todayClockOut ?? DateTime.now();
    return end.difference(_todayClockIn!);
  }

  String get _todayDurationLabel {
    final d = _todayWorkedDuration;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h 0m';
    return '${m}m';
  }

  String _timeLabel(DateTime? time) {
    if (time == null) return '--:--';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handleClockIn() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final scanned = await _showBarcodeModal(
      action: _ClockAction.clockIn,
      userId: user.id,
      userName: user.fullName,
    );
    if (scanned && mounted) {
      setState(() {
        _todayClockIn = DateTime.now();
        _todayClockOut = null;
        _status = _ClockStatus.clockedIn;
      });
      ToastManager().success(context, '출근 처리되었습니다.');
    }
  }

  Future<void> _handleClockOut() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final scanned = await _showBarcodeModal(
      action: _ClockAction.clockOut,
      userId: user.id,
      userName: user.fullName,
    );
    if (scanned && mounted) {
      setState(() {
        _todayClockOut = DateTime.now();
        _status = _ClockStatus.clockedOut;
      });
      ToastManager().success(context, '퇴근 처리되었습니다. 수고하셨습니다!');
    }
  }

  Future<bool> _showBarcodeModal({
    required _ClockAction action,
    required String userId,
    required String userName,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BarcodeBottomSheet(
        action: action,
        userId: userId,
        userName: userName,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        // Current status card
        _CurrentStatusCard(
          status: _status,
          durationLabel: _todayDurationLabel,
          clockInLabel: _timeLabel(_todayClockIn),
          clockOutLabel: _timeLabel(_todayClockOut),
        ),
        const SizedBox(height: 20),

        // Clock action button
        _ClockActionButton(
          status: _status,
          onClockIn: _handleClockIn,
          onClockOut: _handleClockOut,
        ),
        const SizedBox(height: 12),

        // My barcode quick view
        if (user != null)
          _MyBarcodePreview(userId: user.id, userName: user.fullName),
        const SizedBox(height: 28),

        // Recent records header
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            '최근 기록',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ),

        // Recent records list
        ..._mockRecords.map((record) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _RecordCard(
            record: record,
            weekdayLabel: _weekdayShort[record.date.weekday - 1],
          ),
        )),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  Mock Data
  // ═══════════════════════════════════════════════════════════════

  static DateTime _day(int offset) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + offset);
  }

  static final List<_ClockRecord> _mockRecords = [
    _ClockRecord(
      id: 'cr1',
      date: _day(-1),
      clockInTime: _day(-1).add(const Duration(hours: 9, minutes: 0)),
      clockOutTime: _day(-1).add(const Duration(hours: 17, minutes: 30)),
      storeName: 'Cafe Bloom 강남점',
      positionName: '바리스타',
    ),
    _ClockRecord(
      id: 'cr2',
      date: _day(-2),
      clockInTime: _day(-2).add(const Duration(hours: 14, minutes: 0)),
      clockOutTime: _day(-2).add(const Duration(hours: 22, minutes: 0)),
      storeName: 'Bistro Garden 홍대점',
      positionName: '홀 서빙',
    ),
    _ClockRecord(
      id: 'cr3',
      date: _day(-3),
      clockInTime: _day(-3).add(const Duration(hours: 9, minutes: 0)),
      clockOutTime: _day(-3).add(const Duration(hours: 18, minutes: 0)),
      storeName: 'Seoul Station Bakery',
      positionName: '제빵사',
    ),
    _ClockRecord(
      id: 'cr4',
      date: _day(-5),
      clockInTime: _day(-5).add(const Duration(hours: 10, minutes: 0)),
      clockOutTime: _day(-5).add(const Duration(hours: 15, minutes: 0)),
      storeName: 'Cafe Bloom 강남점',
      positionName: '바리스타',
    ),
    _ClockRecord(
      id: 'cr5',
      date: _day(-6),
      clockInTime: _day(-6).add(const Duration(hours: 9, minutes: 0)),
      clockOutTime: _day(-6).add(const Duration(hours: 17, minutes: 0)),
      storeName: 'Bistro Garden 홍대점',
      positionName: '홀 서빙',
    ),
    _ClockRecord(
      id: 'cr6',
      date: _day(-7),
      clockInTime: _day(-7).add(const Duration(hours: 13, minutes: 0)),
      clockOutTime: _day(-7).add(const Duration(hours: 21, minutes: 0)),
      storeName: 'Seoul Station Bakery',
      positionName: '제빵사',
    ),
  ];
}

// ═══════════════════════════════════════════════════════════════
//  Barcode Bottom Sheet
// ═══════════════════════════════════════════════════════════════

class _BarcodeBottomSheet extends StatefulWidget {
  final _ClockAction action;
  final String userId;
  final String userName;

  const _BarcodeBottomSheet({
    required this.action,
    required this.userId,
    required this.userName,
  });

  @override
  State<_BarcodeBottomSheet> createState() => _BarcodeBottomSheetState();
}

class _BarcodeBottomSheetState extends State<_BarcodeBottomSheet> {
  bool _isScanning = false;
  bool _scanComplete = false;
  Timer? _autoCloseTimer;

  String get _barcodeData {
    final prefix = widget.action == _ClockAction.clockIn ? 'IN' : 'OUT';
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return '$prefix-${widget.userId}-$ts';
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  void _simulateScan() {
    setState(() => _isScanning = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _scanComplete = true;
      });
      _autoCloseTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isClockIn = widget.action == _ClockAction.clockIn;
    final actionColor = isClockIn ? AppColors.success : AppColors.danger;
    final actionLabel = isClockIn ? '출근' : '퇴근';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isClockIn ? Icons.login_rounded : Icons.logout_rounded,
                size: 22,
                color: actionColor,
              ),
              const SizedBox(width: 8),
              Text(
                '$actionLabel 바코드',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '아래 바코드를 회사 스캐너에 스캔해주세요',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          // Barcode card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: actionColor.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Column(
              children: [
                // User info
                Text(
                  widget.userName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${widget.userId.length > 8 ? widget.userId.substring(0, 8) : widget.userId}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),

                // Barcode
                BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: _barcodeData,
                  width: 260,
                  height: 80,
                  drawText: false,
                  color: AppColors.text,
                ),
                const SizedBox(height: 8),
                Text(
                  _barcodeData,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppColors.textMuted,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Scan status / button
          if (_scanComplete)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, size: 22, color: AppColors.success),
                  SizedBox(width: 8),
                  Text(
                    '스캔 완료!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                // Simulate scan button (for demo)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isScanning ? null : _simulateScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionColor,
                      disabledBackgroundColor: actionColor.withValues(alpha: 0.6),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white70,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    child: _isScanning
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text('스캔 중...'),
                            ],
                          )
                        : Text('스캔 시뮬레이션 ($actionLabel)'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                  child: const Text('취소'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  My Barcode Preview (small card on main screen)
// ═══════════════════════════════════════════════════════════════

class _MyBarcodePreview extends StatelessWidget {
  final String userId;
  final String userName;

  const _MyBarcodePreview({required this.userId, required this.userName});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullBarcode(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.qr_code_rounded, size: 20, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '내 바코드',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '탭하여 바코드 크게 보기',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _showFullBarcode(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FullBarcodeSheet(userId: userId, userName: userName),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Full Barcode Sheet (view only)
// ═══════════════════════════════════════════════════════════════

class _FullBarcodeSheet extends StatelessWidget {
  final String userId;
  final String userName;

  const _FullBarcodeSheet({required this.userId, required this.userName});

  @override
  Widget build(BuildContext context) {
    final barcodeData = 'EMP-$userId';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            '내 바코드',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '회사 스캐너에 이 바코드를 스캔하세요',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),

          // Barcode area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.accentBg,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 24),
                BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: barcodeData,
                  width: 280,
                  height: 90,
                  drawText: false,
                  color: AppColors.text,
                ),
                const SizedBox(height: 10),
                Text(
                  barcodeData,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: AppColors.textMuted,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: const Text('닫기'),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Current Status Card
// ═══════════════════════════════════════════════════════════════

class _CurrentStatusCard extends StatelessWidget {
  final _ClockStatus status;
  final String durationLabel;
  final String clockInLabel;
  final String clockOutLabel;

  const _CurrentStatusCard({
    required this.status,
    required this.durationLabel,
    required this.clockInLabel,
    required this.clockOutLabel,
  });

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor, statusBg, statusIcon) = switch (status) {
      _ClockStatus.notClockedIn => ('미출근', AppColors.textMuted, const Color(0xFFF3F4F6), Icons.schedule_rounded),
      _ClockStatus.clockedIn => ('근무중', AppColors.success, AppColors.successBg, Icons.play_circle_rounded),
      _ClockStatus.clockedOut => ('퇴근완료', AppColors.accent, AppColors.accentBg, Icons.check_circle_rounded),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Work duration (large)
          Text(
            durationLabel,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: status == _ClockStatus.clockedIn ? AppColors.success : AppColors.text,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '오늘 근무시간',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),

          // Clock in/out time row
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TimeDetail(
                  label: '출근',
                  time: clockInLabel,
                  icon: Icons.login_rounded,
                  color: AppColors.success,
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.border),
              Expanded(
                child: _TimeDetail(
                  label: '퇴근',
                  time: clockOutLabel,
                  icon: Icons.logout_rounded,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeDetail extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;
  final Color color;

  const _TimeDetail({
    required this.label,
    required this.time,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(
          time,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Clock Action Button
// ═══════════════════════════════════════════════════════════════

class _ClockActionButton extends StatelessWidget {
  final _ClockStatus status;
  final VoidCallback onClockIn;
  final VoidCallback onClockOut;

  const _ClockActionButton({
    required this.status,
    required this.onClockIn,
    required this.onClockOut,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _ClockStatus.notClockedIn:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onClockIn,
            icon: const Icon(Icons.login_rounded, size: 20),
            label: const Text('출근하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 18),
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        );
      case _ClockStatus.clockedIn:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onClockOut,
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('퇴근하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 18),
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        );
      case _ClockStatus.clockedOut:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.check_circle_rounded, size: 20),
            label: const Text('오늘 근무 완료'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bg,
              disabledBackgroundColor: AppColors.bg,
              disabledForegroundColor: AppColors.textMuted,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 18),
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  Record Card
// ═══════════════════════════════════════════════════════════════

class _RecordCard extends StatelessWidget {
  final _ClockRecord record;
  final String weekdayLabel;

  const _RecordCard({required this.record, required this.weekdayLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Date column
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(
                  '${record.date.month}/${record.date.day}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  weekdayLabel,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Vertical accent bar
          Container(
            width: 3,
            height: 40,
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
                Text(
                  record.storeName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        record.positionName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.schedule_rounded, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text(
                      '${record.clockInLabel} ~ ${record.clockOutLabel}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Duration
          Text(
            record.durationLabel,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}
