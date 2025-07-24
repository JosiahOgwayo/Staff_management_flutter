import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClockInHistoryPage extends StatelessWidget {
  const ClockInHistoryPage({super.key});

  Stream<QuerySnapshot> _clockInStream() {
    
    final userId = FirebaseAuth.instance.currentUser?.uid;
    return FirebaseFirestore.instance
        .collection('clock_ins')
        .where('uid', isEqualTo: userId)
        .orderBy('clockInTime', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clock-In History')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _clockInStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No clock-ins recorded.'));
          }

          final clockIns = snapshot.data!.docs;

          return ListView.builder(
            itemCount: clockIns.length,
            itemBuilder: (context, index) {
              final data = clockIns[index].data() as Map<String, dynamic>;
              final time = data['clockInTime']?.toDate();
              final status = data['status'] ?? 'N/A';

              return ListTile(
                leading: const Icon(Icons.access_time),
                title: Text('Status: $status'),
                subtitle: Text('Clocked in: ${time != null ? DateFormat('yyyy-MM-dd - h:mm a').format(time) : 'Unknown'}'),
              );
            },
          );
        },
      ),
    );
  }
}
