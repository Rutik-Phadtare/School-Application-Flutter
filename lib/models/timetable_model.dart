class TimetableEntry {
  final String id;
  final String classId;
  final String subject;
  final String teacherId;
  final DateTime startTime;
  final DateTime endTime;
  final String dayOfWeek; // Monday, Tuesday, etc.

  TimetableEntry({
    required this.id,
    required this.classId,
    required this.subject,
    required this.teacherId,
    required this.startTime,
    required this.endTime,
    required this.dayOfWeek,
  });

  factory TimetableEntry.fromMap(String id, Map<String, dynamic> data) {
    return TimetableEntry(
      id: id,
      classId: data['classId'] ?? '',
      subject: data['subject'] ?? '',
      teacherId: data['teacherId'] ?? '',
      startTime: DateTime.parse(data['startTime']),
      endTime: DateTime.parse(data['endTime']),
      dayOfWeek: data['dayOfWeek'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'classId': classId,
      'subject': subject,
      'teacherId': teacherId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'dayOfWeek': dayOfWeek,
    };
  }
}