class ClassModel {
  final String id;
  final String name;
  final String teacherId;
  final List<String> studentIds;
  final String? subject;

  ClassModel({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.studentIds,
    this.subject,
  });

  factory ClassModel.fromMap(String id, Map<String, dynamic> data) {
    return ClassModel(
      id: id,
      name: data['name'] ?? '',
      teacherId: data['teacherId'] ?? '',
      studentIds: List<String>.from(data['studentIds'] ?? []),
      subject: data['subject'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'teacherId': teacherId,
      'studentIds': studentIds,
      'subject': subject,
    };
  }
}