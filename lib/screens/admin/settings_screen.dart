import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _smallBoxController = TextEditingController();
  final TextEditingController _mediumBoxController = TextEditingController();
  final TextEditingController _largeBoxController = TextEditingController();

  final TextEditingController _adminNameController = TextEditingController();
  final TextEditingController _adminEmailController = TextEditingController();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final pricingDoc = await FirebaseFirestore.instance.collection('settings').doc('pricing').get();
    final pricing = pricingDoc.data() ?? {};
    _smallBoxController.text = (pricing['smallBoxPerMeter'] ?? 2).toString();
    _mediumBoxController.text = (pricing['mediumBoxPerMeter'] ?? 3).toString();
    _largeBoxController.text = (pricing['largeBoxPerMeter'] ?? 4).toString();

    final adminDoc = await FirebaseFirestore.instance.collection('settings').doc('adminProfile').get();
    final admin = adminDoc.data() ?? {};
    _adminNameController.text = admin['name'] ?? '';
    _adminEmailController.text = admin['email'] ?? '';

    setState(() {
      _loading = false;
    });
  }

  Future<void> _savePricing() async {
    await FirebaseFirestore.instance.collection('settings').doc('pricing').set({
      'smallBoxPerMeter': double.tryParse(_smallBoxController.text) ?? 2,
      'mediumBoxPerMeter': double.tryParse(_mediumBoxController.text) ?? 3,
      'largeBoxPerMeter': double.tryParse(_largeBoxController.text) ?? 4,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pricing updated!')),
    );
  }

  Future<void> _saveAdminProfile() async {
    await FirebaseFirestore.instance.collection('settings').doc('adminProfile').set({
      'name': _adminNameController.text.trim(),
      'email': _adminEmailController.text.trim(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Admin profile updated!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Box Pricing (per meter)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _smallBoxController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Small Box (₦/meter)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _mediumBoxController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Medium Box (₦/meter)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _largeBoxController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Large Box (₦/meter)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _savePricing,
            child: const Text('Save Pricing'),
          ),
          const Divider(height: 32),
          const Text('Admin Profile', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _adminNameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _adminEmailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _saveAdminProfile,
            child: const Text('Save Profile'),
          ),
              const Divider(height: 32),
    ListTile(
      leading: const Icon(Icons.info),
      title: const Text('About'),
      onTap: () {
        showAboutDialog(
          context: context,
          applicationName: 'Delivery App',
          applicationVersion: '1.0.0',
          applicationLegalese: '© 2025 ABU\n\n'
              'Developers:\n'
              'Ashiru Yusuf Aminu\n'
              '(Ashiruyusufaminu78@gmail.com)\n'
              'Ajeje Musa Boyi\n'
              '(Ajejemusaboyi@gmail.com)',
               );
            },
          ),
        ],
      ),   
    );
  }
}