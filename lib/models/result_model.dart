class ResultModel {
  final String id;
  final String studentId;
  final String subject;
  final String type; // semester, internal, unit
  final double marks;
  final double totalMarks;
  final String semester; // e.g., '1st Semester', '2nd Semester'
  final DateTime date;

  ResultModel({
    required this.id,
    required this.studentId,
    required this.subject,
    required this.type,
    required this.marks,
    required this.totalMarks,
    required this.semester,
    required this.date,
  });

  factory ResultModel.fromMap(String id, Map<String, dynamic> data) {
    return ResultModel(
      id: id,
      studentId: data['studentId'] ?? '',
      subject: data['subject'] ?? '',
      type: data['type'] ?? '',
      marks: (data['marks'] ?? 0).toDouble(),
      totalMarks: (data['totalMarks'] ?? 0).toDouble(),
      semester: data['semester'] ?? '',
      date: DateTime.parse(data['date']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'subject': subject,
      'type': type,
      'marks': marks,
      'totalMarks': totalMarks,
      'semester': semester,
      'date': date.toIso8601String(),
    };
  }
}