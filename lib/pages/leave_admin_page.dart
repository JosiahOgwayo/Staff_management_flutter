import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class LeaveAdminPage extends StatefulWidget {
  const LeaveAdminPage({super.key});

  @override
  State<LeaveAdminPage> createState() => _LeaveAdminPageState();
}

class _LeaveAdminPageState extends State<LeaveAdminPage> {
  bool isLoading = true;
  bool isAdmin = false;
  String selectedStatus = 'all';
  String searchQuery = '';

  final List<String> statusOptions = ['all', 'pending', 'approved', 'denied'];

  @override
  void initState() {
    super.initState();
    checkAdminStatus();
  }

  Future<void> checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        isAdmin = false;
        isLoading = false;
      });
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    setState(() {
      isAdmin = doc.exists && doc['role'] == 'admin';
      isLoading = false;
    });
  }

  Stream<QuerySnapshot> getLeaveRequestsStream() {
    final baseQuery = FirebaseFirestore.instance
        .collection('leave_requests')
        .orderBy('createdAt', descending: true);

    if (selectedStatus == 'all') {
      return baseQuery.snapshots();
    } else {
      return baseQuery.where('status', isEqualTo: selectedStatus).snapshots();
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Future<void> updateLeaveStatus(String docId, String status) async {
    final docRef =
        FirebaseFirestore.instance.collection('leave_requests').doc(docId);
    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists) return;

    await docRef.update({'status': status});

    final userId = docSnapshot['userId'];
    final name = docSnapshot['name'];
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final fcmToken = userDoc['fcmToken'];

    await sendPushNotificationToUser(
        fcmToken, "Leave Request $status", "Hi $name, your leave has been $status.");
  }

  Future<void> sendPushNotificationToUser(
      String token, String title, String body) async {
    final url = Uri.parse('http://127.0.0.1:8000/send-notification/');
    await http.post(url, body: {
      'token': token,
      'title': title,
      'body': body,
    });
  }

  void refreshData() {
    setState(() {}); // Triggers StreamBuilder to reload
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!isAdmin) {
      return const Scaffold(
          body: Center(child: Text('Access Denied. Admins only.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Requests'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: refreshData),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String>(
              value: selectedStatus,
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedStatus = value);
                }
              },
              items: statusOptions.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status[0].toUpperCase() + status.substring(1)),
                );
              }).toList(),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or date (yyyy-mm-dd)',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (value) =>
                  setState(() => searchQuery = value.toLowerCase().trim()),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getLeaveRequestsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No leave requests found'));
          }

          // Apply search filter
          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();

            final startDateObj = _parseDate(data['startDate']);
            final endDateObj = _parseDate(data['endDate']);

            final startDate = startDateObj != null
                ? startDateObj.toString().split(' ')[0]
                : '';
            final endDate = endDateObj != null
                ? endDateObj.toString().split(' ')[0]
                : '';

            return name.contains(searchQuery) ||
                startDate.contains(searchQuery) ||
                endDate.contains(searchQuery);
          }).toList();

          if (docs.isEmpty) {
            return const Center(child: Text('No matching leave requests'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final status = (data['status'] ?? '').toString();

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  title: Text('${data['name']} - ${data['type']}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reason: ${data['reason']}'),
                      Text('From: ${_parseDate(data['startDate']) ?? 'N/A'}'),
                      Text('To: ${_parseDate(data['endDate']) ?? 'N/A'}'),
                      Text(
                        'Status: ${status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : ''}',
                      ),
                    ],
                  ),
                  trailing: status == 'pending'
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () =>
                                  updateLeaveStatus(docs[index].id, 'approved'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () =>
                                  updateLeaveStatus(docs[index].id, 'denied'),
                            ),
                          ],
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
