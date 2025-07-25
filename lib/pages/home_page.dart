import 'package:employee_app_new/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:employee_app_new/pages/profile_page.dart';
import 'package:employee_app_new/pages/admin_dashboard_page.dart';
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      appBar: AppBar(
        title: Text(
          'Staff Management',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.grey,
          elevation: 0.0,
          centerTitle: true,
      ),
      body: FutureBuilder(
        future: AuthService().firestore
            .collection('users')
            .doc(AuthService().currentUser?.uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Welcome'),
              ),
            );
          }
          final data = snapshot.data!.data();
          final firstName = data?['firstName'] ?? AuthService().currentUser?.email ?? '';
          final status = data?['status'] ?? 'offline';
          final statusText = status == 'online' ? 'Online (On work)' : 'Offline (Out of work)';
          final isAdmin = data?['role'] == 'admin';
          return Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome $firstName'),
                  const SizedBox(height: 8),
                  Text('You are currently: $statusText', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (isAdmin) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const AdminDashboardPage()),
                        );
                      },
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Admin Dashboard'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text('My Tasks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  StreamBuilder(
                    stream: AuthService().firestore
                        .collection('tasks')
                        .where('assignedTo', isEqualTo: AuthService().currentUser?.uid)
                        .snapshots(),
                    builder: (context, AsyncSnapshot snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      if (!snapshot.hasData || snapshot.data.docs.isEmpty) {
                        return const Text('No tasks assigned.');
                      }
                      final tasks = snapshot.data.docs;
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index].data() as Map<String, dynamic>;
                          final docId = tasks[index].id;
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              title: Text(task['title'] ?? 'No Title'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (task['description'] != null)
                                    Text('Description: ${task['description']}'),
                                  if (task['status'] != null)
                                    Row(
                                      children: [
                                        const Text('Status: '),
                                        DropdownButton<String>(
                                          value: task['status'],
                                          items: const [
                                            DropdownMenuItem(value: 'pending', child: Text('Pending')),
                                            DropdownMenuItem(value: 'in progress', child: Text('In Progress')),
                                            DropdownMenuItem(value: 'completed', child: Text('Completed')),
                                          ],
                                          onChanged: (newStatus) async {
                                            await AuthService().firestore
                                                .collection('tasks')
                                                .doc(docId)
                                                .update({'status': newStatus});
                                          },
                                        ),
                                      ],
                                    ),
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
            ),
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const ProfilePage()),
                  );
                  
                },
                icon: const Icon(Icons.person),
                label: const Text('Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
