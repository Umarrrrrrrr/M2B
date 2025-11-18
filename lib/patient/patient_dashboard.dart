import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../services/chat_service.dart';
import '../services/subscription_service.dart';
import '../widgets/info_chip.dart';

final _subscriptionService = SubscriptionService();
final _chatService = ChatService();

class PatientDashboard extends StatelessWidget {
  const PatientDashboard({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final uid = user.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Dashboard'),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collection('patients').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data?.data();
          if (data == null) {
            return const Center(child: Text('No profile data yet.'));
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PatientHeader(data: data, emailFallback: user.email),
                const SizedBox(height: 12),
                _SubscriptionStatusBanner(patientId: uid),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showRecordSheet(context, uid),
                      icon: const Icon(Icons.favorite),
                      label: const Text('Add health record'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _promptSubscription(context, uid),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Request doctor'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openChat(context, patientId: uid),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Open chat'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(child: _HealthRecordList(uid: uid)),
              ],
            ),
          );
        },
      ),
    );
  }
}

Future<void> _showRecordSheet(BuildContext context, String uid) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      child: _HealthRecordForm(uid: uid),
    ),
  );
}

Future<void> _promptSubscription(BuildContext context, String patientId) async {
  final messenger = ScaffoldMessenger.of(context);
  final controller = TextEditingController();
  final doctorId = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Request a doctor'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Doctor ID',
          hintText: 'Enter doctor UID',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: const Text('Send request'),
        ),
      ],
    ),
  );

  if (doctorId == null || doctorId.isEmpty) return;
  try {
    await _subscriptionService.requestSubscription(
      patientId: patientId,
      doctorId: doctorId,
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Subscription request sent.')),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Failed to send request: $e')),
    );
  }
}

Future<String?> _promptDoctorId(BuildContext context) async {
  final controller = TextEditingController();
  final messenger = ScaffoldMessenger.of(context);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Enter doctor ID'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Doctor UID',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  if (result == null || result.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Doctor ID required.')),
    );
    return null;
  }
  return result;
}

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({required this.data, required this.emailFallback});

  final Map<String, dynamic> data;
  final String? emailFallback;

  @override
  Widget build(BuildContext context) {
    final name = data['fullName'] as String? ?? 'Patient';
    final email = data['email'] as String? ?? emailFallback ?? 'unknown';
    final gestation = data['gestationalAgeWeeks'];
    final bloodType = data['bloodType'] as String?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(email),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              InfoChip(
                label: 'Gestational age',
                value: gestation != null ? '$gestation weeks' : 'Not set',
              ),
              InfoChip(
                label: 'Blood type',
                value: bloodType ?? 'Unknown',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthRecordList extends StatelessWidget {
  const _HealthRecordList({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final recordsStream = FirebaseFirestore.instance
        .collection('patients')
        .doc(uid)
        .collection('healthRecords')
        .orderBy('recordedAt', descending: true)
        .limit(10)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: recordsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text('No health records yet.'),
          );
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (context, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final record = docs[index].data();
            return _HealthRecordCard(record: record);
          },
        );
      },
    );
  }
}

class _HealthRecordCard extends StatelessWidget {
  const _HealthRecordCard({required this.record});

  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final source = record['source'] as String? ?? 'manual';
    final heartRate = record['heartRate'];
    final bp = record['bloodPressure'] as Map<String, dynamic>?;
    final temp = record['temperature'];
    final ts = record['recordedAt'] as Timestamp?;
    final dateText = ts != null
        ? ts.toDate().toLocal().toString().split('.').first
        : 'Unknown time';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recorded $dateText ($source)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (heartRate != null)
                  InfoChip(label: 'Heart rate', value: '$heartRate bpm'),
                if (bp != null)
                  InfoChip(
                    label: 'Blood pressure',
                    value:
                        '${bp['systolic'] ?? '-'} / ${bp['diastolic'] ?? '-'}',
                  ),
                if (temp != null)
                  InfoChip(label: 'Temperature', value: '$temp °C'),
              ],
            ),
            if (record['notes'] != null) ...[
              const SizedBox(height: 12),
              Text(
                record['notes'] as String,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HealthRecordForm extends StatefulWidget {
  const _HealthRecordForm({required this.uid});

  final String uid;

  @override
  State<_HealthRecordForm> createState() => _HealthRecordFormState();
}

class _HealthRecordFormState extends State<_HealthRecordForm> {
  final _formKey = GlobalKey<FormState>();
  final _heartRateController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _notesController = TextEditingController();
  String _source = 'manual';
  var _submitting = false;

  @override
  void dispose() {
    _heartRateController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _temperatureController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New health record',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _source,
            items: const [
              DropdownMenuItem(value: 'manual', child: Text('Manual input')),
              DropdownMenuItem(value: 'wearable', child: Text('Wearable sync')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _source = value);
              }
            },
            decoration: const InputDecoration(labelText: 'Source'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _heartRateController,
            decoration: const InputDecoration(
              labelText: 'Heart rate (bpm)',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _systolicController,
                  decoration:
                      const InputDecoration(labelText: 'Systolic pressure'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _diastolicController,
                  decoration:
                      const InputDecoration(labelText: 'Diastolic pressure'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _temperatureController,
            decoration: const InputDecoration(
              labelText: 'Temperature (°C)',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save record'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_heartRateController.text.isEmpty &&
        _systolicController.text.isEmpty &&
        _diastolicController.text.isEmpty &&
        _temperatureController.text.isEmpty &&
        _notesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one data point.')),
      );
      return;
    }

    setState(() => _submitting = true);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final heartRate = int.tryParse(_heartRateController.text);
      final systolic = int.tryParse(_systolicController.text);
      final diastolic = int.tryParse(_diastolicController.text);
      final temp = double.tryParse(_temperatureController.text);

      await FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.uid)
          .collection('healthRecords')
          .add({
        'source': _source,
        'heartRate': heartRate,
        'bloodPressure': {
          'systolic': systolic,
          'diastolic': diastolic,
        },
        'temperature': temp,
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'recordedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Record saved.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to save record. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _SubscriptionStatusBanner extends StatelessWidget {
  const _SubscriptionStatusBanner({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('patients')
        .doc(patientId)
        .collection('subscriptions')
        .orderBy('startDate', descending: true)
        .limit(1)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _StatusContainer(
            title: 'No subscription yet',
            message: 'Request a doctor to activate personalized care.',
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          );
        }

        final data = docs.first.data();
        final status = (data['status'] as String? ?? 'pending').toLowerCase();
        final endDate = (data['endDate'] as Timestamp?)?.toDate();
        final graceEnds = (data['graceEndsAt'] as Timestamp?)?.toDate();
        final now = DateTime.now();
        int? daysLeft;
        if (endDate != null) {
          daysLeft = endDate.difference(now).inDays;
        }

        if (status == 'active') {
          if (graceEnds != null && graceEnds.isBefore(now)) {
            return _StatusContainer(
              title: 'Expired',
              message: 'Your subscription has ended. Renew to continue.',
              color: Colors.red[50]!,
            );
          }
          final msg = daysLeft != null && daysLeft >= 0
              ? '$daysLeft day(s) remaining'
              : 'In grace period until ${_formatDate(graceEnds ?? endDate)}';
          return _StatusContainer(
            title: 'Active subscription',
            message: msg,
            color: Colors.green[50]!,
          );
        }

        if (status == 'pending') {
          return _StatusContainer(
            title: 'Pending approval',
            message: 'Waiting for the doctor to approve your request.',
            color: Colors.orange[50]!,
          );
        }

        return _StatusContainer(
          title: 'Subscription $status',
          message: 'Renew or request another doctor to continue.',
          color: Colors.red[50]!,
        );
      },
    );
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return '';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _StatusContainer extends StatelessWidget {
  const _StatusContainer({
    required this.title,
    required this.message,
    required this.color,
  });

  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(message),
        ],
      ),
    );
  }
}


void _openChat(
  BuildContext context, {
  required String patientId,
}) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final doctorId = await _promptDoctorId(context);
  if (doctorId == null) return;
  final hasActive = await _subscriptionService.hasActiveSubscription(
    patientId: patientId,
    doctorId: doctorId,
  );
  if (!hasActive) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('You need an active subscription with this doctor.'),
      ),
    );
    return;
  }
  await _chatService.ensureChatExists(
    patientId: patientId,
    doctorId: doctorId,
  );
  await navigator.push(
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        patientId: patientId,
        doctorId: doctorId,
        currentRole: 'patient',
      ),
    ),
  );
  messenger.showSnackBar(
    const SnackBar(content: Text('Chat ready.')),
  );
}
