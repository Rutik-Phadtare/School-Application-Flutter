import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/result_model.dart';
import '../../models/user_model.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/info_card.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  List<ResultModel> _results = [];
  List<UserModel> _students = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final resultsQuery = await FirebaseFirestore.instance.collection('results').get();
    _results = resultsQuery.docs.map((doc) => ResultModel.fromMap(doc.id, doc.data())).toList();

    final studentsQuery = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student').get();
    _students = studentsQuery.docs.map((doc) => UserModel.fromMap(doc.id, doc.data())).toList();

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Student Results',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addResult,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                final student = _students.firstWhere((s) => s.uid == result.studentId, orElse: () => UserModel(uid: '', name: 'Unknown', email: '', role: ''));
                return InfoCard(
                  title: '${student.name} - ${result.subject}',
                  subtitle: '${result.type} - ${result.marks}/${result.totalMarks} (${result.semester})',
                  icon: Icons.grade,
                  color: Colors.green,
                  onTap: () => _editResult(result),
                );
              },
            ),
    );
  }

  void _addResult() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddResultPage()),
    ).then((_) => _loadData());
  }

  void _editResult(ResultModel result) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddResultPage(result: result)),
    ).then((_) => _loadData());
  }
}

class AddResultPage extends StatefulWidget {
  final ResultModel? result;

  const AddResultPage({super.key, this.result});

  @override
  State<AddResultPage> createState() => _AddResultPageState();
}

class _AddResultPageState extends State<AddResultPage> {
  final _formKey = GlobalKey<FormState>();
  String _studentId = '';
  String _subject = '';
  String _type = 'semester';
  double _marks = 0;
  double _totalMarks = 100;
  String _semester = '1st Semester';

  final List<String> _types = ['semester', 'internal', 'unit'];
  final List<String> _semesters = ['1st Semester', '2nd Semester', '3rd Semester', '4th Semester'];

  @override
  void initState() {
    super.initState();
    if (widget.result != null) {
      _studentId = widget.result!.studentId;
      _subject = widget.result!.subject;
      _type = widget.result!.type;
      _marks = widget.result!.marks;
      _totalMarks = widget.result!.totalMarks;
      _semester = widget.result!.semester;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: widget.result == null ? 'Add Result' : 'Edit Result'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              initialValue: _studentId,
              decoration: const InputDecoration(labelText: 'Student ID'),
              onChanged: (value) => _studentId = value,
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
            TextFormField(
              initialValue: _subject,
              decoration: const InputDecoration(labelText: 'Subject'),
              onChanged: (value) => _subject = value,
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: _types.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
              onChanged: (value) => setState(() => _type = value!),
            ),
            TextFormField(
              initialValue: _marks.toString(),
              decoration: const InputDecoration(labelText: 'Marks'),
              keyboardType: TextInputType.number,
              onChanged: (value) => _marks = double.tryParse(value) ?? 0,
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
            TextFormField(
              initialValue: _totalMarks.toString(),
              decoration: const InputDecoration(labelText: 'Total Marks'),
              keyboardType: TextInputType.number,
              onChanged: (value) => _totalMarks = double.tryParse(value) ?? 100,
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _semester,
              decoration: const InputDecoration(labelText: 'Semester'),
              items: _semesters.map((sem) => DropdownMenuItem(value: sem, child: Text(sem))).toList(),
              onChanged: (value) => setState(() => _semester = value!),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _save,
              child: Text(widget.result == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final result = ResultModel(
      id: widget.result?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      studentId: _studentId,
      subject: _subject,
      type: _type,
      marks: _marks,
      totalMarks: _totalMarks,
      semester: _semester,
      date: DateTime.now(),
    );

    await FirebaseFirestore.instance.collection('results').doc(result.id).set(result.toMap());
    Navigator.pop(context);
  }
}