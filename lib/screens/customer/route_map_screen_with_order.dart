import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class RouteMapScreenWithOrder extends StatefulWidget {
  final LatLng pickup;
  final LatLng dropoff;
  final String apiKey;
  final String pickupAddress;
  final String dropoffAddress;
  final String customerName;

  const RouteMapScreenWithOrder({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.apiKey,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.customerName,
  });

  @override
  State<RouteMapScreenWithOrder> createState() => _RouteMapScreenWithOrderState();
}

class _RouteMapScreenWithOrderState extends State<RouteMapScreenWithOrder> {
  List<LatLng> _polylinePoints = [];
  List<Marker> _markers = [];
  double? distanceMeters;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _showRoute();
  }

  Future<void> _showRoute() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final url =
          'https://api.openrouteservice.org/v2/directions/driving-car?api_key=${widget.apiKey}'
          '&start=${widget.pickup.longitude},${widget.pickup.latitude}'
          '&end=${widget.dropoff.longitude},${widget.dropoff.latitude}';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coordinates = data['features'][0]['geometry']['coordinates'] as List;
        final summary = data['features'][0]['properties']['summary'];
        final distance = summary['distance'] as num?;

        List<LatLng> polylineCoords = coordinates
            .map((c) => LatLng(c[1], c[0]))
            .toList();

        setState(() {
          _polylinePoints = polylineCoords;
          _markers = [
            Marker(
              point: widget.pickup,
              child: const Icon(Icons.location_pin, color: Colors.green, size: 36),
            ),
            Marker(
              point: widget.dropoff,
              child: const Icon(Icons.location_pin, color: Colors.blue, size: 36),
            ),
          ];
          distanceMeters = distance?.toDouble();
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load route. Please try again.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load route. Please check your connection.';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Route & Info')),
        body: Center(child: Text(error!)),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Order Route & Info')),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('orders')
            .where('customer', isEqualTo: widget.customerName)
            .where('status', isEqualTo: 'accepted')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get(),
        builder: (context, orderSnap) {
          if (!orderSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (orderSnap.data!.docs.isEmpty) {
            return const Center(child: Text('No accepted order found.'));
          }
          final order = orderSnap.data!.docs.first.data() as Map<String, dynamic>;
          final acceptedById = order['acceptedById'];
          return Column(
            children: [
              SizedBox(
                height: 250,
                child: FlutterMap(
                  options: MapOptions(
                    center: widget.pickup,
                    zoom: 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    MarkerLayer(markers: _markers),
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
              ),
              if (distanceMeters != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(
                    'Distance: ${distanceMeters!.toStringAsFixed(0)} meters',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pickup: ${widget.pickupAddress}', style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 6),
                    Text('Drop-off: ${widget.dropoffAddress}', style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 6),
                    Text('Status: ${order['status']}', style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 16),
                    if (acceptedById != null && acceptedById.toString().isNotEmpty)
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('agents')
                            .doc(acceptedById)
                            .get(),
                        builder: (context, agentSnap) {
                          if (agentSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!agentSnap.hasData || !agentSnap.data!.exists) {
                            return const Text('Agent info not found.');
                          }
                          final agent = agentSnap.data!.data() as Map<String, dynamic>;
                          return Card(
                            elevation: 2,
                            child: ListTile(
                              leading: agent['profilePicUrl'] != null && agent['profilePicUrl'].toString().isNotEmpty
                                  ? CircleAvatar(
                                      backgroundImage: NetworkImage(agent['profilePicUrl']),
                                      radius: 28,
                                    )
                                  : const CircleAvatar(
                                      child: Icon(Icons.person),
                                      radius: 28,
                                    ),
                              title: Text(agent['name'] ?? 'Agent'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(agent['phone'] ?? ''),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    else
                      const Text('No agent assigned yet.'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}