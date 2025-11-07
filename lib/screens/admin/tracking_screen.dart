import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final TextEditingController _emailController = TextEditingController();
  LatLng? _userLatLng;
  String? _error;

  Future<void> _trackUser() async {
    setState(() {
      _userLatLng = null;
      _error = null;
    });
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = "Please enter an email.");
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('agentLocations')
          .doc(email)
          .get();
      final data = doc.data();
      if (data != null && data['lat'] != null && data['lng'] != null) {
        setState(() {
          _userLatLng = LatLng((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble());
        });
      } else {
        setState(() => _error = "No location found for this user.");
      }
    } catch (e) {
      setState(() => _error = "Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tracking')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'User Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _trackUser,
              child: const Text('Track User'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: _userLatLng == null
                  ? const Center(child: Text('Enter an email to track user location.'))
                  : FlutterMap(
                      options: MapOptions(
                        center: _userLatLng!,
                        zoom: 15,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _userLatLng!,
                              child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}