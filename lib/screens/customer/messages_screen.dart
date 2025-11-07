import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'track_order_screen.dart'; // Assuming this is still used

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Get the current user's email from Firebase Auth
    final String? userEmail = FirebaseAuth.instance.currentUser?.email;

    // Handle case where user is not logged in
    if (userEmail == null || userEmail.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inbox')),
        body: const Center(
          child: Text('Please log in to view your messages.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('messages')
            // FIX: Change 'recipient' to 'recipientId' to match sending code
            .where('recipientId', isEqualTo: userEmail)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final messages = snapshot.data!.docs;
          if (messages.isEmpty) {
            return const Center(child: Text('No messages yet.'));
          }
          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final data = messages[index].data() as Map<String, dynamic>;
              
              // Display the correct fields: 'sender' and 'message'
              final String sender = data['sender'] ?? 'Admin';
              final String messageContent = data['message'] ?? 'No content';
              final Timestamp? timestamp = data['timestamp'] as Timestamp?;
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.message, color: Colors.blue),
                  title: Text('From: $sender'),
                  subtitle: Text(messageContent),
                  trailing: timestamp != null
                      ? Text(
                          timestamp.toDate().toLocal().toString().substring(0, 16),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
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