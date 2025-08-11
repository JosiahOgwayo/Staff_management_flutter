// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LeaveRequestPage extends StatefulWidget {
  const LeaveRequestPage({Key? key}) : super(key: key);

  @override
  State<LeaveRequestPage> createState() => _LeaveRequestPageState();
}

class _LeaveRequestPageState extends State<LeaveRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  String _leaveType = 'Annual';

  final user = FirebaseAuth.instance.currentUser;

  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      String formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
      controller.text = formattedDate;
    }
  }

  Future<void> _submitLeaveRequest() async {
    if (_formKey.currentState!.validate()) {
      // Fetch username once from users collection or fallback to displayName
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      final username = userDoc.data()?['username'] ??
          user!.displayName ??
          'Unknown';

      await FirebaseFirestore.instance.collection('leave_requests').add({
        'userId': user!.uid,
        'username': username, // store username
        'type': _leaveType,
        'reason': _reasonController.text.trim(),
        'startDate': _startDateController.text,
        'endDate': _endDateController.text,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave request submitted')),
      );

      _startDateController.clear();
      _endDateController.clear();
      _reasonController.clear();
      setState(() {
        _leaveType = 'Annual';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Request'),
        backgroundColor: Colors.grey[900],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _leaveType,
                    onChanged: (value) {
                      setState(() {
                        _leaveType = value!;
                      });
                    },
                    items: const [
                      DropdownMenuItem(value: 'Annual', child: Text('Annual')),
                      DropdownMenuItem(value: 'Sick', child: Text('Sick')),
                      DropdownMenuItem(value: 'Maternity', child: Text('Maternity')),
                      DropdownMenuItem(value: 'Emergency', child: Text('Emergency')), // New type
                    ],
                    decoration: const InputDecoration(labelText: 'Leave Type'),
                  ),
                  TextFormField(
                    controller: _reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reason for Leave',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) =>
                        value!.trim().isEmpty ? 'Enter a reason' : null,
                  ),
                  TextFormField(
                    controller: _startDateController,
                    readOnly: true,
                    decoration:
                        const InputDecoration(labelText: 'Start Date'),
                    onTap: () => _selectDate(context, _startDateController),
                    validator: (value) =>
                        value!.isEmpty ? 'Select start date' : null,
                  ),
                  TextFormField(
                    controller: _endDateController,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'End Date'),
                    onTap: () => _selectDate(context, _endDateController),
                    validator: (value) =>
                        value!.isEmpty ? 'Select end date' : null,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _submitLeaveRequest,
                    child: const Text('Submit Request'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Leave requests list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('leave_requests')
                    .where('userId', isEqualTo: user!.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Error: ${snapshot.error.toString()}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text('No leave requests yet'));
                  }

                  final docs = snapshot.data!.docs.toList();
                  docs.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aTime = aData['createdAt'] as Timestamp?;
                    final bTime = bData['createdAt'] as Timestamp?;
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    return bTime.compareTo(aTime);
                  });

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          title: Text(
                              '${data['username']} - ${data['type']} Leave'),
                          subtitle: Text(
                            'Reason: ${data['reason'] ?? ''}\nFrom ${data['startDate']} to ${data['endDate']}\nStatus: ${data['status']}',
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
