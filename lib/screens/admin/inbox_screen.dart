import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Get the current user's email from Firebase Auth
    final String? userEmail = FirebaseAuth.instance.currentUser?.email;

    // Handle case where user is not logged in or email is missing
    if (userEmail == null || userEmail.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inbox')),
        body: const Center(
          child: Text('Please log in to view your inbox.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('messages')
            // FIX: Change 'recipient' to 'recipientId' to match the sending code.
            .where('recipientId', isEqualTo: userEmail)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No messages.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final sender = data['sender'] ?? 'Unknown';
              final senderType = data['senderType'] ?? 'User';
              final message = data['message'] ?? '';
              final time = data['timestamp'] != null
                  ? (data['timestamp'] as Timestamp).toDate()
                  : null;
              
              return ListTile(
                leading: Icon(
                  senderType == 'admin' ? Icons.admin_panel_settings : Icons.person,
                  color: senderType == 'admin' ? Colors.amber : Colors.blue,
                ),
                title: Text('From: $sender'),
                subtitle: Text(message),
                trailing: time != null
                    ? Text(
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}