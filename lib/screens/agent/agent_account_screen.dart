import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AgentAccountScreen extends StatefulWidget {
  const AgentAccountScreen({Key? key}) : super(key: key);

  @override
  State<AgentAccountScreen> createState() => _AgentAccountScreenState();
}

class _AgentAccountScreenState extends State<AgentAccountScreen> {
  String name = '';
  String email = '';
  String phone = '';
  String address = '';
  String vehicleType = '';
  double wallet = 0.0;
  String? profileImageUrl;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileFromFirestore();
  }

  Future<void> _loadProfileFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data != null) {
      setState(() {
        name = data['name'] ?? '';
        email = data['email'] ?? '';
        phone = data['phone'] ?? '';
        address = data['address'] ?? '';
        vehicleType = data['vehicleType'] ?? '';
        wallet = (data['wallet'] ?? 0.0).toDouble();
        profileImageUrl = data['profileImageUrl'];
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _withdrawDialog() async {
    final bankNameController = TextEditingController();
    final accountNumberController = TextEditingController();
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Withdraw'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: bankNameController,
                  decoration: const InputDecoration(labelText: 'Bank Name'),
                ),
                TextField(
                  controller: accountNumberController,
                  decoration: const InputDecoration(labelText: 'Account Number'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final bankName = bankNameController.text.trim();
                final accountNumber = accountNumberController.text.trim();
                final amount = double.tryParse(amountController.text.trim()) ?? 0.0;

                if (bankName.isEmpty || accountNumber.isEmpty || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields with valid values')),
                  );
                  return;
                }
                if (amount > wallet) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Insufficient wallet balance')),
                  );
                  return;
                }

                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  setState(() {
                    wallet -= amount;
                  });
                  await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                    'wallet': wallet,
                  });
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('withdrawals')
                      .add({
                    'amount': amount,
                    'bankName': bankName,
                    'accountNumber': accountNumber,
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                }

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('₦${amount.toStringAsFixed(2)} withdrawn to $bankName ($accountNumber)')),
                );
              },
              child: const Text('Withdraw'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(
                    child: profileImageUrl != null && profileImageUrl!.isNotEmpty
                        ? CircleAvatar(
                            radius: 40,
                            backgroundImage: NetworkImage(profileImageUrl!),
                          )
                        : const CircleAvatar(
                            radius: 40,
                            child: Icon(Icons.person, size: 40),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text('Name: $name', style: const TextStyle(fontSize: 18)),
                  Text('Email: $email', style: const TextStyle(fontSize: 18)),
                  Text('Phone: $phone', style: const TextStyle(fontSize: 18)),
                  Text('Address: $address', style: const TextStyle(fontSize: 18)),
                  Text('Vehicle: $vehicleType', style: const TextStyle(fontSize: 18)),
                  Text('Wallet: ₦${wallet.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, color: Colors.green)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _withdrawDialog,
                    icon: const Icon(Icons.account_balance),
                    label: const Text('Withdraw'),
                  ),
                ],
              ),
            ),
    );
  }
}