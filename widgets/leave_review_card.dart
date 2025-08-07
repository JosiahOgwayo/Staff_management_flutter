import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LeaveReviewCard extends StatelessWidget {
  final String leaveId;
  final String name;
  final String reason;
  final String status;

  const LeaveReviewCard({
    super.key,
    required this.leaveId,
    required this.name,
    required this.reason,
    required this.status,
  });

  Future<void> _sendReview(String decision) async {
    const backendUrl = 'http://127.0.0.1:8000/leave-review/'; 

    final response = await http.post(
      Uri.parse(backendUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "leave_id": leaveId,
        "status": decision, // "approved" or "denied"
      }),
    );

    final result = jsonDecode(response.body);
    debugPrint(result);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListTile(
        title: Text("Leave by $name"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Reason: $reason"),
            Text("Status: $status"),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == 'pending') ...[
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: () => _sendReview("approved"),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => _sendReview("denied"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

