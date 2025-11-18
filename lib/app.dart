import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth/auth_form.dart';
import 'doctor/doctor_dashboard.dart';
import 'patient/patient_dashboard.dart';
import 'services/device_token_registrar.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'M2B',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const AuthForm();
        }

        return FutureBuilder<String?>(
          future: _loadRole(user.uid),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final role = roleSnap.data;
            if (role == null) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Role not found for this account.'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (role == 'patient') {
              return DeviceTokenRegistrar(
                user: user,
                child: PatientDashboard(user: user),
              );
            }
            if (role == 'doctor') {
              return DeviceTokenRegistrar(
                user: user,
                child: DoctorDashboard(user: user),
              );
            }
            return Scaffold(
              appBar: AppBar(
                title: const Text('M2B Dashboard'),
                actions: [
                  IconButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout),
                  ),
                ],
              ),
              body: DeviceTokenRegistrar(
                user: user,
                child: Center(
                  child: Text(
                    'Hi ${user.email ?? 'there'}, role: $role',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

Future<String?> _loadRole(String uid) async {
  final doc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
  if (doc.exists) {
    return doc.data()?['role'] as String?;
  }
  final patientDoc =
      await FirebaseFirestore.instance.collection('patients').doc(uid).get();
  if (patientDoc.exists) return 'patient';
  final doctorDoc =
      await FirebaseFirestore.instance.collection('doctors').doc(uid).get();
  if (doctorDoc.exists) return 'doctor';
  return null;
}
