// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LeaveRequestPage extends StatefulWidget {
  const LeaveRequestPage({super.key});

  @override
  State<LeaveRequestPage> createState() => _LeaveRequestPageState();
}

class _LeaveRequestPageState extends State<LeaveRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController reasonController = TextEditingController();

  DateTime? startDate;
  DateTime? endDate;
  String selectedLeaveType = 'Sick Leave';
  bool isSubmitting = false;

  Future<void> pickDate({required bool isStart}) async {
    DateTime initialDate = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  Future<void> submitLeaveRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both start and end dates')),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('leave_requests').add({
        'userId': 'user?.uid', 
        'name': 'username',    
        'type': selectedLeaveType,
        'reason': reasonController.text,
        'startDate': Timestamp.fromDate(startDate!),
        'endDate': Timestamp.fromDate(endDate!),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave request submitted')),
      );

      reasonController.clear();
      setState(() {
        startDate = null;
        endDate = null;
        selectedLeaveType = 'Sick Leave';
      });
    } catch (e) {
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submission failed')),
      );
    }

    setState(() => isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave Request')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: selectedLeaveType,
                decoration: const InputDecoration(labelText: 'Leave Type'),
                items: const [
                  DropdownMenuItem(value: 'Sick Leave', child: Text('Sick Leave')),
                  DropdownMenuItem(value: 'Annual Leave', child: Text('Annual Leave')),
                  DropdownMenuItem(value: 'Emergency Leave', child: Text('Emergency Leave')),
                ],
                onChanged: (value) => setState(() => selectedLeaveType = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Reason'),
                maxLines: 3,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Please enter a reason' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(startDate == null
                    ? 'Start Date'
                    : DateFormat('yMMMd').format(startDate!)),
                trailing: const Icon(Icons.date_range),
                onTap: () => pickDate(isStart: true),
              ),
              ListTile(
                title: Text(endDate == null
                    ? 'End Date'
                    : DateFormat('yMMMd').format(endDate!)),
                trailing: const Icon(Icons.date_range),
                onTap: () => pickDate(isStart: false),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: isSubmitting ? null : submitLeaveRequest,
                icon: isSubmitting
                    ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    : const Icon(Icons.send),
                label: Text(isSubmitting ? 'Submitting...' : 'Submit Request'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
