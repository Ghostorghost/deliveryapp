import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart';
import 'tracking_screen.dart';
import 'inbox_screen.dart';
import 'send_notification_screen.dart';
import 'orders_screen.dart';
import 'users_screen.dart';
import 'settings_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../auth/welcome_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const Placeholder(),
    const TrackingScreen(),
    const InboxScreen(),
    const SendNotificationScreen(),
    const OrdersScreen(),
    const UsersScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      drawer: _buildDrawer(context),
      body: _selectedIndex == 0
          ? Column(
              children: [
                SizedBox(height: 300, child: AdminLiveMap()),
                Expanded(child: _buildOverview()),
              ],
            )
          : _screens[_selectedIndex],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.amber),
            child: Center(
              child: Text('Admin Menu', style: TextStyle(fontSize: 22)),
            ),
          ),
          _drawerItem(Icons.map, 'Dashboard', 0),
          _drawerItem(Icons.map, 'Tracking', 1),
          _drawerItem(Icons.inbox, 'Inbox', 2),
          _drawerItem(Icons.notifications, 'Send Notification', 3),
          _drawerItem(Icons.list_alt, 'Orders', 4),
          _drawerItem(Icons.people, 'Users', 5),
          _drawerItem(Icons.settings, 'Settings', 6),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log Out'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  ListTile _drawerItem(IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () => _navigateTo(index),
    );
  }

  void _navigateTo(int index) {
    setState(() => _selectedIndex = index);
    Navigator.pop(context);
  }

  Widget _buildOverview() {
    return FutureBuilder<List<QuerySnapshot>>(
      future: Future.wait([
        FirebaseFirestore.instance.collection('orders').get(),
        FirebaseFirestore.instance.collection('users').get(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data![0].docs;
        final userDocs = snapshot.data![1].docs;

        int agentCount = 0, customerCount = 0;
        for (var doc in userDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final role = (data['role'] as String?) ?? '';
          if (role == 'agent') agentCount++;
          if (role == 'customer') customerCount++;
        }

        final pendingCount = orders
            .where((o) => (o['status'] as String?) == 'pending')
            .length;

        final enrouteCount = orders
            .where((o) => (o['status'] as String?) == 'accepted')
            .length;

        final deliveredCount = orders
            .where((o) {
              final s = (o['status'] as String?) ?? '';
              return s == 'dropped' || s == 'delivered';
            })
            .length;

        final cancelledCount = orders
            .where((o) {
              final s = (o['status'] as String?) ?? '';
              return s == 'cancelled' || s == 'declined';
            })
            .length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _statCard('Total Orders', orders.length, Icons.list_alt, Colors.blue),
            _statCard('Pending Orders', pendingCount, Icons.hourglass_top, Colors.amber),
            _statCard('En-Route Orders', enrouteCount, Icons.local_shipping, Colors.lightBlue),
            _statCard('Delivered Orders', deliveredCount, Icons.check_circle, Colors.green),
            _statCard('Cancelled Orders', cancelledCount, Icons.cancel, Colors.red),
            _statCard('Total Agents', agentCount, Icons.motorcycle, Colors.purple),
            _statCard('Total Customers', customerCount, Icons.person, Colors.teal),
          ],
        );
      },
    );
  }

  Widget _statCard(String label, int value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: color, size: 36),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text('$value', style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}

class AdminLiveMap extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('agentLocations').snapshots(),
      builder: (context, agentSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('customerLocations').snapshots(),
          builder: (context, customerSnapshot) {
            List<Marker> markers = [];

            if (agentSnapshot.hasData) {
              for (var doc in agentSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['lat'] != null && data['lng'] != null) {
                  markers.add(
                    Marker(
                      point: LatLng(
                        (data['lat'] as num).toDouble(),
                        (data['lng'] as num).toDouble(),
                      ),
                      child: const Icon(Icons.motorcycle, color: Colors.blue, size: 32),
                    ),
                  );
                }
              }
            }

            if (customerSnapshot.hasData) {
              for (var doc in customerSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['lat'] != null && data['lng'] != null) {
                  markers.add(
                    Marker(
                      point: LatLng(
                        (data['lat'] as num).toDouble(),
                        (data['lng'] as num).toDouble(),
                      ),
                      child: const Icon(Icons.person_pin_circle, color: Colors.green, size: 32),
                    ),
                  );
                }
              }
            }

            return FlutterMap(
              options: MapOptions(
                center: const LatLng(9.05785, 7.49508),
                zoom: 12,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                MarkerLayer(markers: markers),
              ],
            );
          },
        );
      },
    );
  }
}