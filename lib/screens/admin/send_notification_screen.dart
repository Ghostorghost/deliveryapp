import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  bool _sending = false;

  Future<void> _sendNotification() async {
    final recipient = _recipientController.text.trim();
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and body are required')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      final notificationsRef = FirebaseFirestore.instance.collection('notifications');

      if (recipient.isEmpty || recipient.toLowerCase() == 'all') {
        final users = await FirebaseFirestore.instance.collection('users').get();
        for (var doc in users.docs) {
          final data = doc.data();
          final email = data['email'];
          if (email != null) {
            await notificationsRef.add({
              'recipientId': email,
              'title': title,
              'body': body,
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        }

        final agents = await FirebaseFirestore.instance.collection('agentProfiles').get();
        for (var doc in agents.docs) {
          final data = doc.data();
          final email = data['email'];
          if (email != null) {
            await notificationsRef.add({
              'recipientId': email,
              'title': title,
              'body': body,
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        }
      } else {
        await notificationsRef.add({
          'recipientId': recipient,
          'title': title,
          'body': body,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification sent!')),
      );
      _recipientController.clear();
      _titleController.clear();
      _bodyController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Notification')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _recipientController,
              decoration: const InputDecoration(
                labelText: 'Recipient Email or "all"',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            _sending
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('Send Notification'),
                    onPressed: _sendNotification,
                  ),
          ],
        ),
      ),
    );
  }
}
