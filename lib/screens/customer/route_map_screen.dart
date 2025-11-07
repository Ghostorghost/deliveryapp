import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

/// ROUTE MAP SCREEN WITH BOX SELECTION & INFO DROPDOWNS
class RouteMapScreen extends StatefulWidget {
  final LatLng pickup;
  final LatLng dropoff;
  final String? pickupAddress;
  final String? dropoffAddress;
  final String? customerName;
  final String boxLabel;
  final int boxPrice;

  const RouteMapScreen({
    super.key,
    required this.pickup,
    required this.dropoff,
    this.pickupAddress,
    this.dropoffAddress,
    this.customerName,
    required this.boxLabel,
    required this.boxPrice,
  });

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  List<LatLng> _polylinePoints = [];
  List<Marker> _markers = [];
  final String _orsApiKey = '5b3ce3597851110001cf6248f79785442362440f8b78e693df50df3b';

  double? _distanceMeters;
  String? _pickupAddress;
  String? _dropoffAddress;
  int _selectedBox = 0;

  // Firestore‐driven pricing per meter
  double _smallBoxPerMeter = 0.017;
  double _mediumBoxPerMeter = 0.091;
  double _largeBoxPerMeter = 0.11;

  final List<String> _boxImages = [
    'assets/images/small.jpg',
    'assets/images/medium.jpg',
    'assets/images/large.jpg',
  ];

  final List<String> _boxDimensions = [
    '20cm x 15cm x 10cm',
    '40cm x 30cm x 25cm',
    '60cm x 45cm x 40cm',
  ];
  final List<String> _boxWeights = [
    'Up to 5kg',
    'Up to 15kg',
    'Up to 30kg',
  ];
  List<bool> _showBoxInfo = [false, false, false];

  @override
  void initState() {
    super.initState();
    _fetchPricing();
    _setMarkers();
    _drawRoute();
    _getAddress(widget.pickup, isPickup: true);
    _getAddress(widget.dropoff, isPickup: false);
  }

  Future<void> _fetchPricing() async {
    final doc = await FirebaseFirestore.instance.collection('settings').doc('pricing').get();
    final data = doc.data();
    if (data == null) return;
    setState(() {
      _smallBoxPerMeter = data['smallBoxPerMeter'] ?? _smallBoxPerMeter;
      _mediumBoxPerMeter = data['mediumBoxPerMeter'] ?? _mediumBoxPerMeter;
      _largeBoxPerMeter = data['largeBoxPerMeter'] ?? _largeBoxPerMeter;
    });
  }

  void _setMarkers() {
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
  }

  Future<void> _drawRoute() async {
    final url = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/driving-car'
      '?api_key=$_orsApiKey'
      '&start=${widget.pickup.longitude},${widget.pickup.latitude}'
      '&end=${widget.dropoff.longitude},${widget.dropoff.latitude}',
    );
    final response = await http.get(url);
    if (response.statusCode != 200) return;
    final data = json.decode(response.body);
    final coords = data['features'][0]['geometry']['coordinates'] as List;
    final distance = data['features'][0]['properties']['summary']['distance'] as num;
    final polylineCoords = coords.map((c) => LatLng(c[1], c[0])).toList();

    setState(() {
      _polylinePoints = polylineCoords;
      _distanceMeters = distance.toDouble();
    });
  }

  Future<void> _getAddress(LatLng latLng, {required bool isPickup}) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=${latLng.latitude}&lon=${latLng.longitude}&format=json',
    );
    final resp = await http.get(url);
    if (resp.statusCode != 200) return;
    final address = json.decode(resp.body)['display_name'] as String?;
    setState(() {
      if (isPickup) _pickupAddress = address;
      else _dropoffAddress = address;
    });
  }

  double _calculateBoxPrice(int index) {
    if (_distanceMeters == null) return 0;
    final meters = _distanceMeters!.round();
    switch (index) {
      case 1:
        return meters * _mediumBoxPerMeter;
      case 2:
        return meters * _largeBoxPerMeter;
      default:
        return meters * _smallBoxPerMeter;
    }
  }

  void _goToPaymentScreen() {
    final label = ['Small', 'Medium', 'Large'][_selectedBox];
    final price = _calculateBoxPrice(_selectedBox).toInt();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          customerName: widget.customerName ?? '',
          pickup: widget.pickup,
          dropoff: widget.dropoff,
          pickupAddress: _pickupAddress ?? widget.pickupAddress ?? '',
          dropoffAddress: _dropoffAddress ?? widget.dropoffAddress ?? '',
          boxLabel: label,
          boxPrice: price,
          distance: _distanceMeters ?? 0.0,
          boxImage: _boxImages[_selectedBox],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route Map')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Map & Agents Stream
            SizedBox(
              height: 250,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('agentLocations').snapshots(),
                builder: (ctx, snap) {
                  final agentMarkers = <Marker>[];
                  if (snap.hasData) {
                    for (var doc in snap.data!.docs) {
                      final data = doc.data()! as Map<String, dynamic>;
                      final lat = data['lat'];
                      final lng = data['lng'];
                      agentMarkers.add(
                        Marker(
                          point: LatLng(lat, lng),
                          child: const Icon(Icons.directions_bike, color: Colors.orange, size: 28),
                        ),
                      );
                    }
                  }
                  return FlutterMap(
                    options: MapOptions(
                      center: widget.pickup,
                      zoom: 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      MarkerLayer(
                        markers: [
                          ...agentMarkers,
                          ..._markers,
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
                  );
                },
              ),
            ),

            // Distance display
            if (_distanceMeters != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Distance: ${_distanceMeters!.round()} m',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            // Box selection cards + dropdown info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: List.generate(3, (i) {
                  final isSelected = _selectedBox == i;
                  final label = ['Small', 'Medium', 'Large'][i];
                  final price = _calculateBoxPrice(i).toInt();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _selectedBox = i),
                        child: Card(
                          color: isSelected ? Colors.amber[100] : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? Colors.amber : Colors.grey,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Image.asset(_boxImages[i], width: 48, height: 48, fit: BoxFit.cover),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    label,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Text('₦$price', style: const TextStyle(fontSize: 15, color: Colors.black54)),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Show/hide info button
                      TextButton.icon(
                        onPressed: () => setState(() => _showBoxInfo[i] = !_showBoxInfo[i]),
                        icon: Icon(_showBoxInfo[i] ? Icons.expand_less : Icons.expand_more),
                        label: Text(_showBoxInfo[i] ? 'Hide Info' : 'Show Info'),
                      ),

                      // Info panel
                      if (_showBoxInfo[i])
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('📐 Dimensions: ${_boxDimensions[i]}'),
                              Text('⚖️ Weight: ${_boxWeights[i]}'),
                            ],
                          ),
                        ),

                      const SizedBox(height: 8),
                    ],
                  );
                }),
              ),
            ),

            // Confirm Button
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton(
                onPressed: _distanceMeters != null ? _goToPaymentScreen : null,
                child: const Text('Confirm Box',
                    style: TextStyle(fontSize: 18, color: Colors.green)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// PAYMENT & ORDER DETAILS SCREEN
class PaymentScreen extends StatefulWidget {
  final String customerName;
  final LatLng pickup;
  final LatLng dropoff;
  final String pickupAddress;
  final String dropoffAddress;
  final String boxLabel;
  final int boxPrice;
  final double distance;
  final String boxImage;

  const PaymentScreen({
    super.key,
    required this.customerName,
    required this.pickup,
    required this.dropoff,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.boxLabel,
    required this.boxPrice,
    required this.distance,
    required this.boxImage,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _paymentMethod = 'Pay with Cash';
  final _instructionController = TextEditingController();
  bool _isPlacingOrder = false;

  final List<String> _paymentMethods = [
    'Pay with Cash',
    'Pay with Card',
  ];

  Future<void> _placeOrder() async {
    setState(() => _isPlacingOrder = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isPlacingOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login required to place order')),
      );
      return;
    }

    final orderData = {
      'customer': widget.customerName,
      'customerEmail': user.email ?? '',
      'customerId': user.uid,
      'pickup': {'lat': widget.pickup.latitude, 'lng': widget.pickup.longitude},
      'dropoff': {'lat': widget.dropoff.latitude, 'lng': widget.dropoff.longitude},
      'pickupAddress': widget.pickupAddress,
      'dropoffAddress': widget.dropoffAddress,
      'boxLabel': widget.boxLabel,
      'boxPrice': widget.boxPrice,
      'distance': widget.distance,
      'instruction': _instructionController.text,
      'paymentMethod': _paymentMethod,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'acceptedBy': '',
      'acceptedById': '',
      'assignedAgents': <String>[],
      'declinedBy': <String>[],
    };

    try {
      final docRef = await FirebaseFirestore.instance.collection('orders').add(orderData);
      setState(() => _isPlacingOrder = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AgentAssignmentScreen(orderId: docRef.id)),
      );
    } catch (e) {
      setState(() => _isPlacingOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error placing order: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment & Order Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Row(
              children: [
                Image.asset(widget.boxImage, width: 48, height: 48, fit: BoxFit.cover),
                const SizedBox(width: 12),
                Text('${widget.boxLabel} (₦${widget.boxPrice})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Pickup: ${widget.pickupAddress}', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 6),
            Text('Drop-off: ${widget.dropoffAddress}', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 6),
            Text('Distance: ${widget.distance.round()} meters', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 16),
            const Text('Instruction for Agent:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _instructionController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Add any instructions for the agent...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Select Payment Method:', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _paymentMethod,
              items: _paymentMethods
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _paymentMethod = val);
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isPlacingOrder ? null : _placeOrder,
                child: _isPlacingOrder
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Place Order',
                        style: TextStyle(fontSize: 18, color: Colors.green)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// AGENT ASSIGNMENT & ACTION SCREEN
class AgentAssignmentScreen extends StatelessWidget {
  final String orderId;
  const AgentAssignmentScreen({super.key, required this.orderId});

  Future<Map<String, dynamic>?> _getCurrentUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};
    data['uid'] = user.uid;
    data['email'] = user.email;
    return data;
  }

  Future<void> _acceptOrder(BuildContext ctx) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'accepted',
      'acceptedBy': user.email,
      'acceptedById': user.uid,
    });
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Order accepted')));
  }

  Future<void> _declineOrder(BuildContext ctx) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'declinedBy': FieldValue.arrayUnion([uid]),
      'status': 'pending',
    });
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Order declined')));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _getCurrentUserInfo(),
      builder: (ctx, userSnap) {
        if (!userSnap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = userSnap.data!;
        final role = user['role'];
        final uid = user['uid'];

        return Scaffold(
          appBar: AppBar(title: const Text('Agent Assignment')),
          body: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final order = snap.data!.data() as Map<String, dynamic>?;
              if (order == null) return const Center(child: Text('Order not found'));

              final status = order['status'] as String;
              final acceptedBy = order['acceptedBy'] ?? '';
              final acceptedById = order['acceptedById'] ?? '';
              final assigned = List<String>.from(order['assignedAgents'] ?? []);
              final declined = List<String>.from(order['declinedBy'] ?? []);

              // Non-agent users
              if (role != 'agent') {
                if (status == 'accepted') {
                  return Center(
                    child: Text('Agent $acceptedBy has accepted this order!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, color: Colors.green)),
                  );
                }
                return const Center(
                  child: Text('Waiting for an agent to accept this order.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
                );
              }

              // Agent logic
              final alreadyDeclined = declined.contains(uid);
              final alreadyAccepted = acceptedById == uid;
              final canAct = assigned.contains(uid) && !alreadyDeclined && !alreadyAccepted && status == 'pending';

              if (status == 'accepted') {
                return Center(
                  child: Text('Agent $acceptedBy has accepted this order!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, color: Colors.green)),
                );
              }

              if (!canAct) {
                return const Center(
                  child: Text('You cannot take action on this order.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Do you want to accept this order?',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _acceptOrder(context),
                      icon: const Icon(Icons.check),
                      label: const Text('Accept Order'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _declineOrder(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Decline Order'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
