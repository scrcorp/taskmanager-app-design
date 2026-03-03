import 'store.dart';
import 'checklist.dart';

class Assignment {
  final String id;
  final Store store;
  final ShiftInfo shift;
  final PositionInfo position;
  final String status;
  final DateTime workDate;
  final ChecklistSnapshot? checklistSnapshot;
  final DateTime? createdAt;

  const Assignment({
    required this.id,
    required this.store,
    required this.shift,
    required this.position,
    required this.status,
    required this.workDate,
    this.checklistSnapshot,
    this.createdAt,
  });

  String get label => '${store.name} · ${shift.name} · ${position.name}';

  String get statusLabel {
    switch (status) {
      case 'assigned':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  factory Assignment.fromJson(Map<String, dynamic> json) {
    // Server returns flat fields (store_name, shift_name, position_name)
    final checklistRaw = json['checklist_snapshot'];
    ChecklistSnapshot? checklist;
    if (checklistRaw is List) {
      checklist = ChecklistSnapshot.fromItemsList(checklistRaw);
    } else if (checklistRaw is Map<String, dynamic>) {
      checklist = ChecklistSnapshot.fromJson(checklistRaw);
    }

    return Assignment(
      id: json['id'],
      store: Store.fromJson(json['store'] ?? {
        'id': json['store_id'] ?? '',
        'name': json['store_name'] ?? '',
      }),
      shift: ShiftInfo.fromJson(json['shift'] ?? {
        'id': json['shift_id'],
        'name': json['shift_name'] ?? '',
      }),
      position: PositionInfo.fromJson(json['position'] ?? {
        'id': json['position_id'],
        'name': json['position_name'] ?? '',
      }),
      status: json['status'] ?? 'assigned',
      workDate: DateTime.parse(json['work_date']),
      checklistSnapshot: checklist,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}

class ShiftInfo {
  final String? id;
  final String name;

  const ShiftInfo({this.id, required this.name});

  static final _timeRangeRegex = RegExp(r'(\d{2}):(\d{2})-(\d{2}):(\d{2})');

  ({int hour, int minute})? get startTime {
    final match = _timeRangeRegex.firstMatch(name);
    if (match == null) return null;
    return (hour: int.parse(match.group(1)!), minute: int.parse(match.group(2)!));
  }

  ({int hour, int minute})? get endTime {
    final match = _timeRangeRegex.firstMatch(name);
    if (match == null) return null;
    return (hour: int.parse(match.group(3)!), minute: int.parse(match.group(4)!));
  }

  bool isWithinShiftHours(DateTime dateTime) {
    final start = startTime;
    final end = endTime;
    if (start == null || end == null) return true;
    final nowMin = dateTime.hour * 60 + dateTime.minute;
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;
    if (endMin < startMin) {
      return nowMin >= startMin || nowMin <= endMin;
    }
    return nowMin >= startMin && nowMin <= endMin;
  }

  factory ShiftInfo.fromJson(Map<String, dynamic> json) {
    return ShiftInfo(id: json['id'], name: json['name'] ?? '');
  }
}

class PositionInfo {
  final String? id;
  final String name;

  const PositionInfo({this.id, required this.name});

  factory PositionInfo.fromJson(Map<String, dynamic> json) {
    return PositionInfo(id: json['id'], name: json['name'] ?? '');
  }
}
