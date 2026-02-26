enum ShiftApplicationStatus {
  available,
  pending,
  approved,
  rejected,
}

class ScheduleShift {
  final String id;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String shiftName;
  final String storeName;
  final String positionName;
  final int totalSlots;
  final int filledSlots;
  final ShiftApplicationStatus status;

  const ScheduleShift({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.shiftName,
    required this.storeName,
    required this.positionName,
    required this.totalSlots,
    this.filledSlots = 0,
    this.status = ShiftApplicationStatus.available,
  });

  int get availableSlots => totalSlots - filledSlots;
  bool get isFull => availableSlots <= 0;
  String get timeRange => '$startTime - $endTime';

  ScheduleShift copyWith({
    ShiftApplicationStatus? status,
    int? filledSlots,
  }) {
    return ScheduleShift(
      id: id,
      date: date,
      startTime: startTime,
      endTime: endTime,
      shiftName: shiftName,
      storeName: storeName,
      positionName: positionName,
      totalSlots: totalSlots,
      filledSlots: filledSlots ?? this.filledSlots,
      status: status ?? this.status,
    );
  }
}
