import 'package:employee_app_new/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:employee_app_new/pages/profile_page.dart';
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
          return Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Welcome $firstName'),
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
