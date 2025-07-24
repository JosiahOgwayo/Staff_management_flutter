import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:employee_app_new/auth_service.dart';
import 'package:intl/intl.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  Future<bool> _isAdmin() async {
    final user = AuthService().currentUser;
    if (user == null) return false;
    final doc = await AuthService().firestore.collection('users').doc(user.uid).get();
    return doc.data()?['role'] == 'admin';
  }

  Future<List<Map<String, dynamic>>> _fetchEmployees() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    return snapshot.docs
      .where((doc) => doc.data()['role'] != 'admin')
      .map((doc) => {'uid': doc.id, ...doc.data()})
      .toList();
  }

  void _showCreateTaskDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    String? title, description, assignedTo;
    String status = 'pending';
    List<Map<String, dynamic>> employees = await _fetchEmployees();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create & Assign Task'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (v) => v == null || v.isEmpty ? 'Enter title' : null,
                        onChanged: (v) => title = v,
                      ),
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Description'),
                        onChanged: (v) => description = v,
                      ),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Assign To'),
                        items: employees.map((e) => DropdownMenuItem<String>(
                          value: e['uid'] as String,
                          child: Text((e['firstName'] ?? e['email'] ?? e['uid']).toString()),
                        )).toList(),
                        onChanged: (v) => assignedTo = v,
                        validator: (v) => v == null ? 'Select employee' : null,
                      ),
                      DropdownButtonFormField<String>(
                        value: status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'in progress', child: Text('In Progress')),
                          DropdownMenuItem(value: 'completed', child: Text('Completed')),
                        ],
                        onChanged: (v) => setState(() { status = v!; }),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  await FirebaseFirestore.instance.collection('tasks').add({
                    'title': title,
                    'description': description,
                    'assignedTo': assignedTo,
                    'status': status,
                    'createdAt': DateTime.now().toIso8601String(),
                  });

                  // Show in-app notification (SnackBar)
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Task assigned to employee!'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: FutureBuilder<bool>(
        future: _isAdmin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!) {
            return const Center(child: Text('Access denied. Admins only.'));
          }
          return SingleChildScrollView(
            child: Column(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('clock_ins')
                      .where('status', isEqualTo: 'clocked_in')
                      .where('clockInTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                      .snapshots(),
                  builder: (context, clockInSnapshot) {
                    if (clockInSnapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    final users = clockInSnapshot.data?.docs ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Clocked-in Users (Today):', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ...users.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final timeStr = data['clockInTime']?.toDate() != null
                              ? DateFormat('E h:mm a').format(data['clockInTime'].toDate())
                              : 'N/A';
                          return ListTile(
                            title: Text(data['name'] ?? data['email'] ?? data['uid']),
                            subtitle: Text('Clock-in Time: $timeStr'),
                          );
                        }),
                      ],
                    );
                  },
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('tasks').snapshots(),
                  builder: (context, taskSnapshot) {
                    if (taskSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (taskSnapshot.hasError) {
                      return Center(child: Text('Error: ${taskSnapshot.error}'));
                    }
                    final tasks = taskSnapshot.data?.docs ?? [];
                    if (tasks.isEmpty) {
                      return const Center(child: Text('No tasks found.'));
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index].data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          child: ListTile(
                            title: Text(task['title'] ?? 'No Title'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (task['description'] != null)
                                  Text('Description: ${task['description']}'),
                                if (task['assignedTo'] != null)
                                  Text('Assigned To: ${task['assignedTo']}'),
                                if (task['status'] != null)
                                  Text('Status: ${task['status']}'),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FutureBuilder<bool>(
        future: _isAdmin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.data == true) {
            if (!context.mounted) return const SizedBox.shrink();
            return FloatingActionButton(
              onPressed: () => _showCreateTaskDialog(context),
              tooltip: 'Create & Assign Task',
              child: const Icon(Icons.add),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
