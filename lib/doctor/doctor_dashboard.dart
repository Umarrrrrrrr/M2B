import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../services/chat_service.dart';
import '../services/subscription_service.dart';
import '../widgets/info_chip.dart';

final _subscriptionService = SubscriptionService();
final _chatService = ChatService();

class DoctorDashboard extends StatelessWidget {
  const DoctorDashboard({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final uid = user.uid;
    final doctorDoc =
        FirebaseFirestore.instance.collection('doctors').doc(uid).snapshots();
    final linksQuery = FirebaseFirestore.instance
        .collection('doctors')
        .doc(uid)
        .collection('patients')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: doctorDoc,
        builder: (context, profileSnap) {
          if (profileSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = profileSnap.data?.data();
          if (profile == null) {
            return const Center(child: Text('Doctor profile not found.'));
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DoctorHeader(profile: profile, emailFallback: user.email),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Verification flow will be added soon.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.verified_user),
                      label: Text(profile['isVerified'] == true
                          ? 'Verified'
                          : 'Submit docs'),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
                const SizedBox(height: 24),
                _PendingRequestsList(doctorId: uid),
                const SizedBox(height: 24),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: linksQuery,
                    builder: (context, linkSnap) {
                      if (linkSnap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      final links = linkSnap.data?.docs ?? [];
                      if (links.isEmpty) {
                        return const Center(
                          child: Text('No subscribed patients yet.'),
                        );
                      }
                      return ListView.separated(
                        itemCount: links.length,
                        separatorBuilder: (context, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final link = links[index].data();
                          final patientId = link['patientId'] as String?;
                          if (patientId == null) {
                            return const SizedBox.shrink();
                          }
                          return _DoctorPatientTile(
                            patientId: patientId,
                            subscriptionId: link['subscriptionId'] as String?,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DoctorHeader extends StatelessWidget {
  const _DoctorHeader({required this.profile, required this.emailFallback});

  final Map<String, dynamic> profile;
  final String? emailFallback;

  @override
  Widget build(BuildContext context) {
    final name = profile['fullName'] as String? ?? 'Doctor';
    final email = profile['email'] as String? ?? emailFallback ?? 'unknown';
    final specialization = profile['specialization'] as String?;
    final experience = profile['experienceYears'];
    final verified = profile['isVerified'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(email),
                  ],
                ),
              ),
              Icon(
                verified ? Icons.verified : Icons.verified_outlined,
                color: verified
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              InfoChip(
                label: 'Specialization',
                value: specialization ?? 'Not set',
              ),
              InfoChip(
                label: 'Experience',
                value: experience != null ? '$experience yrs' : 'Unknown',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingRequestsList extends StatelessWidget {
  const _PendingRequestsList({required this.doctorId});

  final String doctorId;

  @override
  Widget build(BuildContext context) {
    final pendingStream = FirebaseFirestore.instance
        .collection('subscriptions')
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return SizedBox(
      height: 220,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: pendingStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Card(
              child: ListTile(
                title: Text('No pending requests.'),
              ),
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            separatorBuilder: (context, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              return SizedBox(
                width: 320,
                child: _PendingRequestTile(
                  subscriptionId: doc.id,
                  patientId: doc.data()['patientId'] as String,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PendingRequestTile extends StatelessWidget {
  const _PendingRequestTile({
    required this.subscriptionId,
    required this.patientId,
  });

  final String subscriptionId;
  final String patientId;

  @override
  Widget build(BuildContext context) {
    final patientFuture = FirebaseFirestore.instance
        .collection('patients')
        .doc(patientId)
        .get();
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: patientFuture,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = data?['fullName'] as String? ?? 'Patient';
        final email = data?['email'] as String? ?? '';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (email.isNotEmpty) Text(email),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => _approve(context),
                      child: const Text('Approve'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _approve(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _subscriptionService.approveSubscription(
        subscriptionId: subscriptionId,
        doctorId: FirebaseAuth.instance.currentUser!.uid,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Subscription activated.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to approve: $e')),
      );
    }
  }
}

Future<void> _openChat(
  BuildContext context, {
  required String doctorId,
  String? patientId,
  Map<String, dynamic>? patientData,
}) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final pid = patientId ?? patientData?['patientId'] as String?;
  if (pid == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Patient data missing.')),
    );
    return;
  }
  await _chatService.ensureChatExists(
    patientId: pid,
    doctorId: doctorId,
  );
  await navigator.push(
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        patientId: pid,
        doctorId: doctorId,
        currentRole: 'doctor',
      ),
    ),
  );
}

class _DoctorPatientTile extends StatelessWidget {
  const _DoctorPatientTile({
    required this.patientId,
    this.subscriptionId,
  });

  final String patientId;
  final String? subscriptionId;

  @override
  Widget build(BuildContext context) {
    final patientDoc =
        FirebaseFirestore.instance.collection('patients').doc(patientId).get();
    final latestRecord = FirebaseFirestore.instance
        .collection('patients')
        .doc(patientId)
        .collection('healthRecords')
        .orderBy('recordedAt', descending: true)
        .limit(1)
        .get();

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: patientDoc,
      builder: (context, patientSnap) {
        if (patientSnap.connectionState == ConnectionState.waiting) {
          return const Card(
            child: ListTile(
              title: Text('Loading patient...'),
            ),
          );
        }
        final patient = patientSnap.data?.data();
        if (patient == null) {
          return const SizedBox.shrink();
        }
        return Card(
          child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: latestRecord,
            builder: (context, recordSnap) {
              final record = recordSnap.data?.docs.first.data();
              return ListTile(
                title: Text(patient['fullName'] as String? ?? 'Unnamed patient'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient['email'] as String? ?? 'No email'),
                    if (record != null)
                      Text(
                        'HR: ${record['heartRate'] ?? '-'} bpm • BP: ${record['bloodPressure']?['systolic'] ?? '-'} / ${record['bloodPressure']?['diastolic'] ?? '-'}',
                      ),
                    if (subscriptionId != null)
                      Text('Subscription: $subscriptionId'),
                  ],
                ),
                trailing: IconButton(
                  onPressed: () {
                    _openChat(
                      context,
                      doctorId: FirebaseAuth.instance.currentUser!.uid,
                      patientId: patientId,
                      patientData: patient,
                    );
                  },
                  icon: const Icon(Icons.message),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
