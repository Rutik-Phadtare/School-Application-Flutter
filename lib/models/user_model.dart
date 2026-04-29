class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // admin, teacher, student, parent
  final String? classId; // for students
  final String? teacherId; // for parents
  final Map<String, dynamic>? additionalData;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.classId,
    this.teacherId,
    this.additionalData,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? '',
      classId: data['classId'],
      teacherId: data['teacherId'],
      additionalData: data,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'classId': classId,
      'teacherId': teacherId,
      ...?additionalData,
    };
  }
}