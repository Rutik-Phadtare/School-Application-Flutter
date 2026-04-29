import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/custom_app_bar.dart';

class AddMultipleStudentsPage extends StatefulWidget {
  const AddMultipleStudentsPage({super.key});

  @override
  State<AddMultipleStudentsPage> createState() => _AddMultipleStudentsPageState();
}

class _AddMultipleStudentsPageState extends State<AddMultipleStudentsPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  String _message = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Add Multiple Students'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Enter one student per line in the format: Name, Email, Class',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'John Doe,john@example.com,10-A',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_message.isNotEmpty)
              Text(_message, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _saveStudents,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Students'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveStudents() async {
    final lines = _controller.text.trim().split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      setState(() => _message = 'Please enter at least one student.');
      return;
    }

    setState(() {
      _loading = true;
      _message = '';
    });

    var successCount = 0;
    var failCount = 0;

    for (final line in lines) {
      final parts = line.split(',').map((part) => part.trim()).toList();
      if (parts.length < 3) {
        failCount++;
        continue;
      }
      final name = parts[0];
      final email = parts[1];
      final className = parts[2];

      try {
        final doc = FirebaseFirestore.instance.collection('users').doc();
        await doc.set({
          'name': name,
          'email': email,
          'class': className,
          'role': 'student',
          'createdAt': FieldValue.serverTimestamp(),
        });
        successCount++;
      } catch (_) {
        failCount++;
      }
    }

    setState(() {
      _loading = false;
      _message = 'Created $successCount students, failed $failCount lines.';
    });
  }
}
