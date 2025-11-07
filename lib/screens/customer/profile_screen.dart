import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';


class ProfileScreen extends StatefulWidget {
  final String name;
  final String email;
  final String phone;
  final String address;
  final File? profileImage;
  final Function(String, String, String, String, File?) onProfileUpdated;
  final double? walletBalance;
  final ValueChanged<double>? onWalletChanged;

  const ProfileScreen({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.profileImage,
    required this.onProfileUpdated,
    this.walletBalance,
    this.onWalletChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController addressController;
  File? _image;
  bool _saving = false;
  double walletBalance = 0.0;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.name);
    emailController = TextEditingController(text: widget.email);
    phoneController = TextEditingController(text: widget.phone);
    addressController = TextEditingController(text: widget.address);
    _image = widget.profileImage;
    walletBalance = widget.walletBalance ?? 0.0;
    _loadProfile();
    _loadProfileImage();

  }

Future<void> _loadProfileImage() async {
  try {
    final box = await Hive.openBox('customerProfile');
    final imagePath = box.get('profileImagePath');
    if (imagePath != null && File(imagePath).existsSync()) {
      setState(() {
        _image = File(imagePath);
      });
    } else {
      setState(() {
        _image = null;
      });
    }
  } catch (e) {
    setState(() {
      _image = null;
    });
  }
}
   Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data != null) {
      nameController.text = data['name'] ?? '';
      emailController.text = data['email'] ?? '';
      phoneController.text = data['phone'] ?? '';
      addressController.text = data['address'] ?? '';
      walletBalance = (data['wallet'] ?? widget.walletBalance ?? 0.0).toDouble();
    }
    final box = await Hive.openBox('customerProfile');
    final imagePath = box.get('profileImagePath');
    if (imagePath != null && File(imagePath).existsSync()) {
      _image = File(imagePath);
    }
    setState(() => isLoading = false);
  }
 
  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'name': nameController.text,
          'email': emailController.text,
          'phone': phoneController.text,
          'address': addressController.text,
          'wallet': walletBalance,
          'profileImagePath': _image?.path ?? '',
        }, SetOptions(merge: true));
      }

      widget.onProfileUpdated(
        nameController.text,
        emailController.text,
        phoneController.text,
        addressController.text,
        _image,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
      });
      final box = await Hive.openBox('customerProfile');
      await box.put('profileImagePath', picked.path);
    }
  }


  ImageProvider _getProfileImage() {
    if (_image != null) return FileImage(_image!);
    return const AssetImage('assets/images/profile_placeholder.png');
  }

  void _editWalletBalance() async {
    if (widget.onWalletChanged == null) return;

    final controller = TextEditingController(text: walletBalance.toString());
    final newBalance = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Wallet'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Wallet Balance'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null) Navigator.pop(context, val);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newBalance != null) {
      setState(() => walletBalance = newBalance);
      widget.onWalletChanged!(walletBalance);
      await _saveProfile();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(radius: 50, backgroundImage: _getProfileImage()),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _pickImage,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: emailController, readOnly: true, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 12),
            TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: Colors.amber),
              title: const Text('Wallet Balance'),
              subtitle: Text('₦${walletBalance.toStringAsFixed(2)}'),
              trailing: widget.onWalletChanged != null
                  ? IconButton(icon: const Icon(Icons.edit), onPressed: _editWalletBalance)
                  : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _saveProfile,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
