import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/timetable_model.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/info_card.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  List<TimetableEntry> _timetable = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    setState(() => _loading = true);
    final query = await FirebaseFirestore.instance.collection('timetable').get();
    _timetable = query.docs.map((doc) => TimetableEntry.fromMap(doc.id, doc.data())).toList();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Lecture Timetable',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addTimetableEntry,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _timetable.length,
              itemBuilder: (context, index) {
                final entry = _timetable[index];
                return InfoCard(
                  title: '${entry.subject} - ${entry.dayOfWeek}',
                  subtitle: '${entry.startTime.hour}:${entry.startTime.minute.toString().padLeft(2, '0')} - ${entry.endTime.hour}:${entry.endTime.minute.toString().padLeft(2, '0')}',
                  icon: Icons.schedule,
                  color: Colors.blue,
                  onTap: () => _editTimetableEntry(entry),
                );
              },
            ),
    );
  }

  void _addTimetableEntry() {
    // Navigate to add/edit screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTimetableEntryPage()),
    ).then((_) => _loadTimetable());
  }

  void _editTimetableEntry(TimetableEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTimetableEntryPage(entry: entry)),
    ).then((_) => _loadTimetable());
  }
}

class AddTimetableEntryPage extends StatefulWidget {
  final TimetableEntry? entry;

  const AddTimetableEntryPage({super.key, this.entry});

  @override
  State<AddTimetableEntryPage> createState() => _AddTimetableEntryPageState();
}

class _AddTimetableEntryPageState extends State<AddTimetableEntryPage> {
  final _formKey = GlobalKey<FormState>();
  String _classId = '';
  String _subject = '';
  String _teacherId = '';
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now();
  String _dayOfWeek = 'Monday';

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      _classId = widget.entry!.classId;
      _subject = widget.entry!.subject;
      _teacherId = widget.entry!.teacherId;
      _startTime = TimeOfDay.fromDateTime(widget.entry!.startTime);
      _endTime = TimeOfDay.fromDateTime(widget.entry!.endTime);
      _dayOfWeek = widget.entry!.dayOfWeek;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: widget.entry == null ? 'Add Timetable Entry' : 'Edit Timetable Entry'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              initialValue: _classId,
              decoration: const InputDecoration(labelText: 'Class ID'),
              onChanged: (value) => _classId = value,
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
            TextFormField(
              initialValue: _subject,
              decoration: const InputDecoration(labelText: 'Subject'),
              onChanged: (value) => _subject = value,
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
            TextFormField(
              initialValue: _teacherId,
              decoration: const InputDecoration(labelText: 'Teacher ID'),
              onChanged: (value) => _teacherId = value,
              validator: (value) => value!.isEmpty ? 'Required' : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _dayOfWeek,
              decoration: const InputDecoration(labelText: 'Day of Week'),
              items: _days.map((day) => DropdownMenuItem(value: day, child: Text(day))).toList(),
              onChanged: (value) => setState(() => _dayOfWeek = value!),
            ),
            ListTile(
              title: const Text('Start Time'),
              subtitle: Text(_startTime.format(context)),
              onTap: () async {
                final time = await showTimePicker(context: context, initialTime: _startTime);
                if (time != null) setState(() => _startTime = time);
              },
            ),
            ListTile(
              title: const Text('End Time'),
              subtitle: Text(_endTime.format(context)),
              onTap: () async {
                final time = await showTimePicker(context: context, initialTime: _endTime);
                if (time != null) setState(() => _endTime = time);
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _save,
              child: Text(widget.entry == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final startDateTime = DateTime(2023, 1, 1, _startTime.hour, _startTime.minute);
    final endDateTime = DateTime(2023, 1, 1, _endTime.hour, _endTime.minute);

    final entry = TimetableEntry(
      id: widget.entry?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      classId: _classId,
      subject: _subject,
      teacherId: _teacherId,
      startTime: startDateTime,
      endTime: endDateTime,
      dayOfWeek: _dayOfWeek,
    );

    await FirebaseFirestore.instance.collection('timetable').doc(entry.id).set(entry.toMap());
    Navigator.pop(context);
  }
}