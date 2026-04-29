class AttendanceModel {
  final String id;
  final String studentId;
  final String classId;
  final DateTime date;
  final bool present;
  final String? faceImageUrl; // for face recognition
  final String markedBy; // teacher or admin uid

  AttendanceModel({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.date,
    required this.present,
    this.faceImageUrl,
    required this.markedBy,
  });

  factory AttendanceModel.fromMap(String id, Map<String, dynamic> data) {
    return AttendanceModel(
      id: id,
      studentId: data['studentId'] ?? '',
      classId: data['classId'] ?? '',
      date: DateTime.parse(data['date']),
      present: data['present'] ?? false,
      faceImageUrl: data['faceImageUrl'],
      markedBy: data['markedBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'classId': classId,
      'date': date.toIso8601String(),
      'present': present,
      'faceImageUrl': faceImageUrl,
      'markedBy': markedBy,
    };
  }
}