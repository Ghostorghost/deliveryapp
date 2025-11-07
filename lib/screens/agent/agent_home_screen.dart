import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';

import 'agent_profile_screen.dart';
import 'agent_messages_screen.dart';
import 'agent_notifications_screen.dart';
import 'agent_settings_screen.dart';
import 'agent_account_screen.dart';
import 'agent_my_rides_screen.dart';
import '../auth/welcome_screen.dart';

class AgentHome extends StatefulWidget {
  const AgentHome({super.key});

  @override
  State<AgentHome> createState() => _AgentHomeState();
}

class _AgentHomeState extends State<AgentHome> {
  int _selectedIndex = 0;

  String vehicleType = 'bike';
  File? profileImage;

  Location location = Location();
  LatLng? currentLatLng;

  final String orsApiKey = '5b3ce3597851110001cf6248f79785442362440f8b78e693df50df3b';

  static const Color _agentAppColor = Color.fromARGB(255, 184, 204, 2);
  static const Color _drawerHeaderColor = Color.fromARGB(255, 190, 127, 10);

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadProfileVehicleType();
    _loadProfileImage();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadProfileImage() async {
    try {
      final box = await Hive.openBox('agentProfile');
      final imagePath = box.get('profileImagePath');
      if (imagePath != null && File(imagePath).existsSync()) {
        setState(() {
          profileImage = File(imagePath);
        });
      } else {
        setState(() {
          profileImage = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile image from Hive: $e');
      setState(() {
        profileImage = null;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locData = await location.getLocation();
      if (locData.latitude != null && locData.longitude != null) {
        setState(() {
          currentLatLng = LatLng(locData.latitude!, locData.longitude!);
        });
        _uploadAgentLocation();
      } else {
        debugPrint('Location data is null.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to get current location. Please enable location services.')),
          );
        }
      }
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        debugPrint('Location permission denied.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied. Please enable it in settings.')),
          );
        }
      } else if (e.code == 'PERMISSION_DENIED_NEVER_ASK') {
        debugPrint('Location permission denied forever.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied permanently. Please enable it manually.')),
          );
        }
      }
      currentLatLng = const LatLng(6.5244, 3.3792);
    } catch (e) {
      debugPrint('Error getting current location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting current location: ${e.toString()}')),
        );
      }
      currentLatLng = const LatLng(6.5244, 3.3792);
    }
  }

  Future<void> _loadProfileVehicleType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        if (data['vehicleType'] != null) {
          setState(() {
            vehicleType = data['vehicleType'];
          });
          _uploadAgentLocation();
        }
      }
    } catch (e) {
      debugPrint('Error loading vehicle type: $e');
    }
  }

  Future<void> _uploadAgentLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (currentLatLng == null || user == null) return;
    try {
      await FirebaseFirestore.instance.collection('agentLocations').doc(user.uid).set({
        'lat': currentLatLng!.latitude,
        'lng': currentLatLng!.longitude,
        'vehicleType': vehicleType,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error uploading agent location: $e');
    }
  }

  void _onDrawerItemTap(String item) async {
    Navigator.pop(context);
    Widget? screen;
    switch (item) {
      case 'Profile':
        screen = const AgentProfileScreen();
        break;
      case 'Messages':
        screen = const AgentMessagesScreen();
        break;
      case 'Notifications':
        screen = const AgentNotificationsScreen();
        break;
      case 'Settings':
        screen = const AgentSettingsScreen();
        break;
      case 'Logout':
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            (Route<dynamic> route) => false,
          );
        }
        return;
    }
    if (screen != null) {
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
      }
    }
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildHomeContent() {
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('agentLocations').snapshots(),
            builder: (context, snapshot) {
              List<Marker> agentMarkers = [];
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final lat = data['lat'];
                  final lng = data['lng'];
                  agentMarkers.add(
                    Marker(
                      point: LatLng(lat, lng),
                      child: Icon(
                        data['vehicleType'] == 'car'
                            ? Icons.directions_car
                            : data['vehicleType'] == 'tricycle'
                                ? Icons.electric_rickshaw
                                : Icons.directions_bike,
                        color: Colors.orange,
                        size: 32,
                      ),
                    ),
                  );
                }
              }
              if (currentLatLng != null) {
                agentMarkers.add(
                  Marker(
                    point: currentLatLng!,
                    child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 36),
                  ),
                );
              }
              return FlutterMap(
                options: MapOptions(
                  center: currentLatLng ?? const LatLng(6.5244, 3.3792),
                  zoom: 14,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  MarkerLayer(markers: agentMarkers),
                ],
              );
            },
          ),
        ),
        const Expanded(
          child: AgentMyRidesScreen(),
        ),
      ],
    );
  }

  Widget _buildOrdersContent() {
    return const AgentMyRidesScreen();
  }

  Widget _buildAccountContent() {
    return const AgentAccountScreen();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_selectedIndex) {
      case 0:
        body = _buildHomeContent();
        break;
      case 1:
        body = _buildOrdersContent();
        break;
      case 2:
        body = _buildAccountContent();
        break;
      default:
        body = _buildHomeContent();
    }

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Dashboard'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: _drawerHeaderColor),
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              child: FutureBuilder<DocumentSnapshot>(
                future: user != null
                    ? FirebaseFirestore.instance.collection('users').doc(user.uid).get()
                    : null,
                builder: (context, snapshot) {
                  String name = 'Agent';
                  String email = '';
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  }
                  if (snapshot.hasError) {
                    debugPrint('Error fetching user data for drawer: ${snapshot.error}');
                  }
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    name = data['name'] ?? 'Agent';
                    email = data['email'] ?? '';
                  }
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundImage: profileImage != null
                              ? FileImage(profileImage!)
                              : const AssetImage('assets/images/profile_placeholder.png') as ImageProvider,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontSize: 20),
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                    ],
                  );
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () => _onDrawerItemTap('Profile'),
            ),
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text('Messages'),
              onTap: () => _onDrawerItemTap('Messages'),
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              onTap: () => _onDrawerItemTap('Notifications'),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () => _onDrawerItemTap('Settings'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () => _onDrawerItemTap('Logout'),
            ),
          ],
        ),
      ),
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home, color: Color.fromARGB(255, 216, 212, 4), size: 38),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt, color: Color.fromARGB(255, 216, 212, 4), size: 38),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle, color: Color.fromARGB(255, 216, 212, 4), size: 38),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}