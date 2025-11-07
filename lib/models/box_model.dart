// lib/models/box_model.dart (or directly in route_map_screen.dart)
class Box {
  final String label;
  final String imagePath;
  final String dimensions;
  final String weightCapacity;
  double pricePerMeter; // This will be updated from Firestore

  Box({
    required this.label,
    required this.imagePath,
    required this.dimensions,
    required this.weightCapacity,
    this.pricePerMeter = 0.0, // Default value, will be fetched
  });
}