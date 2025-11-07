import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AccountScreen extends StatefulWidget {
  final double? walletBalance;
  final ValueChanged<double>? onWalletChanged;

  const AccountScreen({super.key, this.walletBalance, this.onWalletChanged});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  double walletBalance = 0.00;
  double cardBalance = 0.00;
  String cardNumber = '';
  String cardHolder = '';
  String expiryDate = '';
  String cardCVV = '';
  final TextEditingController _topUpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();

    if (data != null) {
      setState(() {
        cardNumber = data['cardNumber'] ?? '';
        cardHolder = data['cardHolder'] ?? '';
        expiryDate = data['expiryDate'] ?? '';
        cardCVV = data['cardCVV'] ?? '';
        cardBalance = (data['cardBalance'] ?? 0.0).toDouble();
        walletBalance = (data['wallet'] ?? widget.walletBalance ?? 0.0).toDouble();
      });
    }
  }

  Future<void> _syncToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'email': user.email,
      'cardNumber': cardNumber,
      'cardHolder': cardHolder,
      'expiryDate': expiryDate,
      'cardCVV': cardCVV,
      'cardBalance': cardBalance,
      'wallet': walletBalance,
    }, SetOptions(merge: true));
  }

  void _showTopUpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Top Up Wallet'),
        content: TextField(
          controller: _topUpController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount', prefixText: '₦'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _topUpController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(_topUpController.text);
              if (amount != null && amount > 0) {
                if (cardNumber.isEmpty || cardBalance < amount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Check card details or balance.')),
                  );
                } else {
                  setState(() {
                    walletBalance += amount;
                    cardBalance -= amount;
                  });
                  await _syncToFirestore();
                  widget.onWalletChanged?.call(walletBalance);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('₦$amount transferred to wallet')),
                  );
                }
              }
              _topUpController.clear();
            },
            child: const Text('Top Up'),
          ),
        ],
      ),
    );
  }

  void _showEditCardDialog() {
    final numberCtrl = TextEditingController(text: cardNumber);
    final holderCtrl = TextEditingController(text: cardHolder);
    final expiryCtrl = TextEditingController(text: expiryDate);
    final cvvCtrl = TextEditingController(text: cardCVV);
    final balanceCtrl = TextEditingController(text: cardBalance.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Set Up Card Info'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: numberCtrl,
                keyboardType: TextInputType.number,
                maxLength: 16,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Card Number'),
              ),
              TextField(
                controller: holderCtrl,
                decoration: const InputDecoration(labelText: 'Card Holder'),
              ),
              TextField(
                controller: expiryCtrl,
                keyboardType: TextInputType.number,
                maxLength: 5,
                inputFormatters: [ExpiryDateFormatter()],
                decoration: const InputDecoration(labelText: 'Expiry Date (MM/YY)'),
              ),
              TextField(
                controller: cvvCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 3,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'CVV'),
              ),
              TextField(
                controller: balanceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Card Balance'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                cardNumber = numberCtrl.text;
                cardHolder = holderCtrl.text;
                expiryDate = expiryCtrl.text;
                cardCVV = cvvCtrl.text;
                cardBalance = double.tryParse(balanceCtrl.text) ?? 0.0;
              });
              await _syncToFirestore();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Card info saved')));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _topUpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              color: Colors.amber[50],
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet, color: Colors.amber, size: 36),
                title: const Text('Wallet Balance', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('₦${walletBalance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20)),
                trailing: ElevatedButton(onPressed: _showTopUpDialog, child: const Text('Top Up')),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.blue[50],
              child: ListTile(
                leading: const Icon(Icons.credit_card, color: Colors.blue, size: 36),
                title: const Text('Card Info', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: cardNumber.isEmpty
                    ? const Text('No card set up. Tap edit to add one.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Number: $cardNumber'),
                          Text('Holder: $cardHolder'),
                          Text('Expiry: $expiryDate'),
                          Text('CVV: ${cardCVV.replaceAll(RegExp(r"."), "*")}'),
                          Text('Card Balance: ₦${cardBalance.toStringAsFixed(2)}'),
                        ],
                      ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: _showEditCardDialog,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 4) text = text.substring(0, 4);
    if (text.length >= 3) {
      text = '${text.substring(0, 2)}/${text.substring(2)}';
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
