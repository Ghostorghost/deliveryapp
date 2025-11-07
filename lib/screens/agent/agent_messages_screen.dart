import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AgentMessagesScreen extends StatelessWidget {
  const AgentMessagesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get the current agent's email.
    final String? agentEmail = FirebaseAuth.instance.currentUser?.email;

    // Handle the case where agentEmail might be null (e.g., user not logged in)
    if (agentEmail == null || agentEmail.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Messages')),
        body: const Center(
          child: Text('Please log in to view your messages.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('messages')
            // FIX: Ensure this is 'recipientId' to match the sending code
            .where('recipientId', isEqualTo: agentEmail)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No messages yet.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final msg = docs[i].data() as Map<String, dynamic>;
              // 'message' and 'sender' fields from your admin's sending code.
              final messageContent = msg['message'] ?? 'No message content';
              final sender = msg['sender'] ?? 'Unknown Sender';
              final timestamp = msg['timestamp'] != null
                  ? (msg['timestamp'] as Timestamp).toDate().toLocal().toString().substring(0, 16)
                  : '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: ListTile(
                  leading: const Icon(Icons.email),
                  title: Text('From: $sender'),
                  subtitle: Text(messageContent),
                  trailing: Text(
                    timestamp,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}