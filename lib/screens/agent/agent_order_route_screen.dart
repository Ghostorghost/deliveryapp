import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AgentOrderRouteScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const AgentOrderRouteScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final pickup = order['pickup'];
    final dropoff = order['dropoff'];
    final pickupLatLng = LatLng(pickup['lat'], pickup['lng']);
    final dropoffLatLng = LatLng(dropoff['lat'], dropoff['lng']);

    final markers = [
      Marker(
        point: pickupLatLng,
        child: const Icon(Icons.location_pin, color: Colors.green, size: 36),
      ),
      Marker(
        point: dropoffLatLng,
        child: const Icon(Icons.location_pin, color: Colors.red, size: 36),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Order Route')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 250,
              child: FlutterMap(
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
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [pickupLatLng, dropoffLatLng],
                        strokeWidth: 5,
                        color: Colors.blue,
                      ),
                    ],
                  ),
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
          ],
        ),
      ),
    );
  }
}