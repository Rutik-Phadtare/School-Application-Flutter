import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/attendance_model.dart';
import '../../models/user_model.dart';
import '../../services/face_recognition_service.dart';
import '../../widgets/custom_app_bar.dart';

class AttendancePage extends StatefulWidget {
  final String? classId;

  const AttendancePage({super.key, this.classId});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late CameraController _cameraController;
  late FaceRecognitionService _faceService;
  List<UserModel> _students = [];
  Map<String, bool> _attendance = {};
  bool _isLoading = true;
  List<String> _availableClasses = [];
  String? _selectedClass;

  @override
  void initState() {
    super.initState();
    _faceService = FaceRecognitionService();
    _initializeCamera();
    _loadClasses();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    _cameraController = CameraController(cameras[0], ResolutionPreset.medium);
    await _cameraController.initialize();
    setState(() {});
  }

  Future<void> _loadClasses() async {
    final classQuery = await FirebaseFirestore.instance.collection('classes').get();
    _availableClasses = classQuery.docs
        .map((doc) => (doc.data() as Map)['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
    _selectedClass = widget.classId ?? (_availableClasses.isNotEmpty ? _availableClasses.first : null);
    if (_selectedClass != null) {
      await _loadStudentsForClass(_selectedClass!);
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStudentsForClass(String className) async {
    setState(() => _isLoading = true);
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('class', isEqualTo: className)
        .get();
    _students = query.docs.map((doc) => UserModel.fromMap(doc.id, doc.data())).toList();
    _attendance = {for (var student in _students) student.uid: false};
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _faceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Mark Attendance'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_availableClasses.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedClass,
                      decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                      items: _availableClasses
                          .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedClass = value;
                          });
                          _loadStudentsForClass(value);
                        }
                      },
                    ),
                  ),
                Expanded(
                  flex: 2,
                  child: _cameraController.value.isInitialized
                      ? CameraPreview(_cameraController)
                      : const Center(child: CircularProgressIndicator()),
                ),
                Expanded(
                  flex: 3,
                  child: _students.isEmpty
                      ? const Center(child: Text('No students found for the selected class.'))
                      : ListView.builder(
                          itemCount: _students.length,
                          itemBuilder: (context, index) {
                            final student = _students[index];
                            return CheckboxListTile(
                              title: Text(student.name),
                              value: _attendance[student.uid] ?? false,
                              onChanged: (value) => setState(() => _attendance[student.uid] = value ?? false),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: _students.isEmpty ? null : _markAttendanceWithFace,
                    child: const Text('Mark with Face Recognition'),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _markAttendanceWithFace() async {
    try {
      final image = await _cameraController.takePicture();
      final file = File(image.path);
      final faces = await _faceService.detectFaces(file);

      if (faces.isNotEmpty) {
        // For demo, mark all as present if face detected
        setState(() {
          for (var student in _students) {
            _attendance[student.uid] = true;
          }
        });
        await _saveAttendance();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance marked successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No face detected. Try again.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _saveAttendance() async {
    final date = DateTime.now();
    for (var student in _students) {
      final attendance = AttendanceModel(
        id: '${student.uid}_${date.toIso8601String().split('T')[0]}',
        studentId: student.uid,
        classId: _selectedClass ?? '',
        date: date,
        present: _attendance[student.uid] ?? false,
        markedBy: 'admin', // Assuming admin
      );
      await FirebaseFirestore.instance.collection('attendance').doc(attendance.id).set(attendance.toMap());
    }
  }
}