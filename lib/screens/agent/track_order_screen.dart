import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class TrackOrderScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const TrackOrderScreen({super.key, required this.order});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  List<LatLng> _polylinePoints = [];
  LatLng? agentLatLng;
  late LatLng pickupLatLng;
  late LatLng dropoffLatLng;
  late String agentEmail;
  String agentVehicleType = 'bike';
  bool _loadingRoute = false;

  @override
  void initState() {
    super.initState();
    final pickup = widget.order['pickup'];
    final dropoff = widget.order['dropoff'];
    pickupLatLng = LatLng((pickup['lat'] as num).toDouble(), (pickup['lng'] as num).toDouble());
    dropoffLatLng = LatLng((dropoff['lat'] as num).toDouble(), (dropoff['lng'] as num).toDouble());
    agentEmail = widget.order['acceptedBy'] ?? '';
    _fetchRoute();
    _listenToAgentLocation();
  }

  Future<void> _fetchRoute() async {
    setState(() => _loadingRoute = true);
    const orsApiKey = '5b3ce3597851110001cf6248f79785442362440f8b78e693df50df3b';
    final url =
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$orsApiKey&start=${pickupLatLng.longitude},${pickupLatLng.latitude}&end=${dropoffLatLng.longitude},${dropoffLatLng.latitude}';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coordinates = data['features'][0]['geometry']['coordinates'] as List;
        List<LatLng> polylineCoords = coordinates.map((c) => LatLng(c[1], c[0])).toList();
        setState(() {
          _polylinePoints = polylineCoords;
          _loadingRoute = false;
        });
      } else {
        setState(() => _loadingRoute = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch route: ${response.body}')),
        );
      }
    } catch (e) {
      setState(() => _loadingRoute = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching route: $e')),
      );
    }
  }

  void _listenToAgentLocation() {
    if (agentEmail.isEmpty) return;
    FirebaseFirestore.instance
        .collection('agentLocations')
        .doc(agentEmail)
        .snapshots()
        .listen((doc) async {
      final data = doc.data();
      if (data != null && data['lat'] != null && data['lng'] != null) {
        final position = LatLng(
          (data['lat'] as num).toDouble(),
          (data['lng'] as num).toDouble(),
        );
        if (data['vehicleType'] != null && data['vehicleType'] != agentVehicleType) {
          setState(() {
            agentVehicleType = data['vehicleType'];
          });
        }
        setState(() {
          agentLatLng = position;
        });
      }
    });
  }

  Icon _getAgentIcon(String type) {
    if (type == 'car') {
      return const Icon(Icons.directions_car, color: Colors.blue, size: 36);
    } else if (type == 'tricycle') {
      return const Icon(Icons.electric_rickshaw, color: Colors.blue, size: 36);
    }
    return const Icon(Icons.directions_bike, color: Colors.blue, size: 36);
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      Marker(
        point: pickupLatLng,
        child: const Icon(Icons.location_pin, color: Colors.green, size: 36),
      ),
      Marker(
        point: dropoffLatLng,
        child: const Icon(Icons.location_pin, color: Colors.red, size: 36),
      ),
    ];

    if (agentLatLng != null) {
      markers.add(
        Marker(
          point: agentLatLng!,
          child: _getAgentIcon(agentVehicleType),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Track Package Live')),
      body: _loadingRoute
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: MapOptions(
                center: pickupLatLng,
                zoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                MarkerLayer(markers: markers),
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
    );
  }
}
