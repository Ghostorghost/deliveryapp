import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  void _deleteUser(BuildContext context, String userId, String role) async {
    if (role == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin users cannot be deleted')),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting user: $e')),
      );
    }
  }

  void _banUser(BuildContext context, String userId, bool isBanned, String role) async {
    if (role == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin users cannot be banned')),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'banned': !isBanned});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isBanned ? 'User unbanned' : 'User banned')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // FIX: Simplified the function to only accept the email.
  void _messageUser(BuildContext context, String email) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Message $email'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final msg = controller.text.trim();
              if (msg.isNotEmpty) {
                try {
                  await FirebaseFirestore.instance.collection('messages').add({
                    'sender': 'admin',
                    'senderType': 'admin',
                    'recipientId': email, // Now using the clean 'email' variable
                    'message': msg,
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message sent')),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error sending message: $e')),
                  );
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _addUser(BuildContext context) {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              final name = nameController.text.trim();
              if (email.isNotEmpty && name.isNotEmpty) {
                await FirebaseFirestore.instance.collection('users').doc(email).set({
                  'email': email,
                  'name': name,
                  'createdAt': FieldValue.serverTimestamp(),
                  'banned': false,
                  'role': 'customer',
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User added')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add User',
            onPressed: () => _addUser(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No users found.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final userId = docs[i].id; 
              final email = data['email'] ?? userId;
              final name = data['name'] ?? '';
              final role = data['role'] ?? 'customer';
              final banned = data['banned'] == true;
              final createdAt = data['createdAt'] is Timestamp
                  ? (data['createdAt'] as Timestamp).toDate()
                  : null;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(
                    role == 'admin' ? Icons.admin_panel_settings : Icons.person,
                    color: role == 'admin' ? Colors.amber : Colors.blue,
                  ),
                  title: Text('$name (${role.toUpperCase()})'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email: $email'),
                      if (createdAt != null)
                        Text('Joined: ${createdAt.toLocal().toString().split(' ')[0]}'),
                      if (banned)
                        const Text('Status: BANNED', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteUser(context, userId, role);
                      } else if (value == 'ban') {
                        _banUser(context, userId, banned, role);
                      } else if (value == 'message') {
                        // FIX: Pass only the email variable.
                        _messageUser(context, email);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'message', child: Text('Message')),
                      if (role != 'admin')
                        PopupMenuItem(
                          value: 'ban',
                          child: Text(banned ? 'Unban' : 'Ban'),
                        ),
                      if (role != 'admin')
                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
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