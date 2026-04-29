import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';
import '../models/class_model.dart';
import '../models/attendance_model.dart';
import '../models/result_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // User operations
  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(user.uid, doc.data()!);
  }

  Future<List<UserModel>> getUsersByRole(String role) async {
    final query = await _firestore.collection('users').where('role', isEqualTo: role).get();
    return query.docs.map((doc) => UserModel.fromMap(doc.id, doc.data())).toList();
  }

  Future<void> updateUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  // Class operations
  Future<List<ClassModel>> getClasses() async {
    final query = await _firestore.collection('classes').get();
    return query.docs.map((doc) => ClassModel.fromMap(doc.id, doc.data())).toList();
  }

  Future<void> addClass(ClassModel classModel) async {
    await _firestore.collection('classes').doc(classModel.id).set(classModel.toMap());
  }

  // Attendance operations
  Future<List<AttendanceModel>> getAttendanceForClass(String classId, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final query = await _firestore.collection('attendance')
        .where('classId', isEqualTo: classId)
        .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('date', isLessThan: end.toIso8601String())
        .get();
    return query.docs.map((doc) => AttendanceModel.fromMap(doc.id, doc.data())).toList();
  }

  Future<void> markAttendance(AttendanceModel attendance) async {
    await _firestore.collection('attendance').doc(attendance.id).set(attendance.toMap());
  }

  // Results operations
  Future<List<ResultModel>> getResultsForStudent(String studentId) async {
    final query = await _firestore.collection('results').where('studentId', isEqualTo: studentId).get();
    return query.docs.map((doc) => ResultModel.fromMap(doc.id, doc.data())).toList();
  }

  Future<void> addResult(ResultModel result) async {
    await _firestore.collection('results').doc(result.id).set(result.toMap());
  }

  // Upload image to Firebase Storage
  Future<String> uploadImage(String path, String fileName) async {
    final ref = _storage.ref().child(path).child(fileName);
    await ref.putFile(File(fileName)); // Assuming file is passed
    return await ref.getDownloadURL();
  }
}