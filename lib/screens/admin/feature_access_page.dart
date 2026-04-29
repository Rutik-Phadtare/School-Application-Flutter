import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/custom_app_bar.dart';

class FeatureAccessPage extends StatefulWidget {
  const FeatureAccessPage({super.key});

  @override
  State<FeatureAccessPage> createState() => _FeatureAccessPageState();
}

class _FeatureAccessPageState extends State<FeatureAccessPage> {
  bool _loading = true;
  List<DocumentSnapshot> _users = [];

  final Map<String, String> _features = {
    'attendance': 'Online Attendance',
    'announcements': 'Announcements',
    'timetable': 'Lecture Timetable',
    'results': 'Results',
    'messages': 'Messages',
  };

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: ['teacher', 'parent'])
        .get();
    setState(() {
      _users = query.docs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Feature Access Control'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final data = user.data() as Map<String, dynamic>;
                final name = data['name'] ?? 'Unknown';
                final role = data['role'] ?? 'user';
                final permissions = Map<String, dynamic>.from(data['allowedFeatures'] ?? {});
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ExpansionTile(
                    title: Text('$name (${role.capitalize()})'),
                    subtitle: Text(user.id),
                    children: _features.entries.map((feature) {
                      final enabled = permissions[feature.key] ?? true;
                      return SwitchListTile(
                        title: Text(feature.value),
                        value: enabled,
                        onChanged: (value) => _toggleFeature(user.id, feature.key, value),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _toggleFeature(String uid, String feature, bool value) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'allowedFeatures': {feature: value}
    }, SetOptions(merge: true));
    _loadUsers();
  }
}

extension StringCasingExtension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
