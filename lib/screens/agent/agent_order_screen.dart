import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class AgentOrderScreen extends StatefulWidget {
  final String orderId;
  const AgentOrderScreen({super.key, required this.orderId});

  @override
  State<AgentOrderScreen> createState() => _AgentOrderScreenState();
}

class _AgentOrderScreenState extends State<AgentOrderScreen> {
  List<LatLng> _polylinePoints = [];
  bool _loadingRoute = false;

  Future<void> markOrderAsDropped(BuildContext context) async {
    final orderRef = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

    await orderRef.update({'status': 'dropped'});

    final orderSnap = await orderRef.get();
    final orderData = orderSnap.data() as Map<String, dynamic>?;

    if (orderData != null) {
      if (orderData['customerId'] != null) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'recipientId': orderData['customerId'],
          'orderId': widget.orderId,
          'title': 'Order Dropped Off',
          'body': 'Your order has been dropped off. Please confirm delivery.',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (orderData['paymentMethod'] == 'wallet' && orderData['boxPrice'] != null && orderData['acceptedBy'] != null) {
        final agentEmail = orderData['acceptedBy'];
        final amount = (orderData['boxPrice'] is int)
            ? (orderData['boxPrice'] as int).toDouble()
            : (orderData['boxPrice'] as num).toDouble();

        final agentDoc = FirebaseFirestore.instance.collection('agentProfiles').doc(agentEmail);
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(agentDoc);
          final currentWallet = (snapshot.data()?['wallet'] ?? 0.0) as num;
          transaction.update(agentDoc, {'wallet': currentWallet + amount});
        });
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order marked as dropped. Customer notified.')),
    );
  }

  Future<void> _fetchRoute(LatLng pickup, LatLng dropoff) async {
    setState(() {
      _loadingRoute = true;
    });
    const orsApiKey = '5b3ce3597851110001cf6248f79785442362440f8b78e693df50df3b';
    final url =
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$orsApiKey&start=${pickup.longitude},${pickup.latitude}&end=${dropoff.longitude},${dropoff.latitude}';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final coordinates = data['features'][0]['geometry']['coordinates'] as List;
      List<LatLng> polylineCoords = coordinates
          .map((c) => LatLng(c[1], c[0]))
          .toList();

      setState(() {
        _polylinePoints = polylineCoords;
        _loadingRoute = false;
      });
    } else {
      setState(() {
        _loadingRoute = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch route')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agent Order')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final order = snapshot.data!.data() as Map<String, dynamic>?;
          if (order == null) {
            return const Center(child: Text('Order not found.'));
          }

          final pickup = order['pickup'];
          final dropoff = order['dropoff'];
          if (pickup == null || dropoff == null) {
            return const Center(child: Text('Order location data missing.'));
          }
          final pickupLatLng = LatLng(
            (pickup['lat'] as num).toDouble(),
            (pickup['lng'] as num).toDouble(),
          );
          final dropoffLatLng = LatLng(
            (dropoff['lat'] as num).toDouble(),
            (dropoff['lng'] as num).toDouble(),
          );

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_polylinePoints.isEmpty && !_loadingRoute) {
              _fetchRoute(pickupLatLng, dropoffLatLng);
            }
          });

          final String instructions = order['instruction'] ?? 'No special instructions.';

          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: 250,
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          center: pickupLatLng,
                          zoom: 13,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c'],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: pickupLatLng,
                                child: const Icon(Icons.location_pin, color: Colors.green, size: 36),
                              ),
                              Marker(
                                point: dropoffLatLng,
                                child: const Icon(Icons.location_pin, color: Colors.red, size: 36),
                              ),
                            ],
                          ),
                          if (_polylinePoints.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _polylinePoints,
                                  strokeWidth: 5,
                                  color: Colors.blue,
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (_loadingRoute)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text('Pickup Address'),
                  subtitle: Text(order['pickupAddress'] ?? ''),
                ),
                ListTile(
                  title: const Text('Drop-off Address'),
                  subtitle: Text(order['dropoffAddress'] ?? ''),
                ),
                ListTile(
                  title: const Text('Special Instructions'),
                  subtitle: Text(instructions),
                ),
                ListTile(
                  title: const Text('Status'),
                  subtitle: Text(order['status'] ?? ''),
                ),
                const SizedBox(height: 16),
                if ((order['status'] ?? '').toString().toLowerCase() == 'dropped')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      color: Colors.amber[100],
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: const [
                            Icon(Icons.local_shipping, color: Colors.amber),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Order Has Been Dropped',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if ((order['status'] ?? '').toString().toLowerCase() != 'dropped')
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: () => markOrderAsDropped(context),
                      child: const Text('Order Has Been Dropped'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}