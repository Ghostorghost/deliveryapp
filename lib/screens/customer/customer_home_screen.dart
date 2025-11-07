import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import '../auth/welcome_screen.dart';

import 'profile_screen.dart';
import 'account_screen.dart';
import 'my_rides_screen.dart';
import 'messages_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'route_map_screen.dart';

enum BoxSize { small, medium, large }

class CustomerHome extends StatefulWidget {
  final ValueChanged<ThemeMode>? onThemeChanged;
  const CustomerHome({super.key, this.onThemeChanged});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  final String apiKey = '5b3ce3597851110001cf6248f79785442362440f8b78e693df50df3b';

  final TextEditingController pickupController = TextEditingController();
  final TextEditingController dropoffController = TextEditingController();

  final FocusNode pickupFocus = FocusNode();
  final FocusNode dropoffFocus = FocusNode();

  List<dynamic> pickupSuggestions = [];
  List<dynamic> dropoffSuggestions = [];

  dynamic selectedPickup;
  dynamic selectedDropoff;

  Timer? _debounce;
  bool isLoadingSuggestions = false;
  bool showPickupSuggestions = false;
  bool showDropoffSuggestions = false;

  Location location = Location();
  LatLng? currentLatLng;
  int _selectedIndex = 0;

  String profileName = '';
  String profileEmail = '';
  String profilePhone = '';
  String profileAddress = '';
  double walletBalance = 0.0;
  File? profileImage;

  BoxSize? selectedBox;
  int selectedBoxPrice = 0;
  String selectedBoxSize = '';

  List<LatLng> _polylinePoints = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadProfileFromFirestore();
    _loadProfileImage();

    pickupFocus.addListener(() {
      if (mounted) {
        setState(() {
          showPickupSuggestions = pickupFocus.hasFocus;
          if (!pickupFocus.hasFocus) {
            pickupSuggestions = [];
          }
        });
      }
    });

    dropoffFocus.addListener(() {
      if (mounted) {
        setState(() {
          showDropoffSuggestions = dropoffFocus.hasFocus;
          if (!dropoffFocus.hasFocus) {
            dropoffSuggestions = [];
          }
        });
      }
    });
  }

  @override
  void dispose() {
    pickupController.dispose();
    dropoffController.dispose();
    pickupFocus.dispose();
    dropoffFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadProfileImage() async {
    try {
      final box = await Hive.openBox('customerProfile');
      final imagePath = box.get('profileImagePath');
      if (imagePath != null && File(imagePath).existsSync()) {
        if (mounted) {
          setState(() {
            profileImage = File(imagePath);
          });
        }
      } else {
        if (mounted) {
          setState(() {
            profileImage = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          profileImage = null;
        });
      }
    }
  }

  Future<void> _loadProfileFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('customers').doc(uid).get();
    final data = userDoc.data();

    if (data != null && mounted) {
      setState(() {
        profileName = data['name'] ?? '';
        profileEmail = data['email'] ?? '';
        profilePhone = data['phone'] ?? '';
        profileAddress = data['address'] ?? '';
        walletBalance = (data['wallet'] ?? 0.0).toDouble();
      });
    }
  }

  Future<void> _saveProfileToFirestore({
    required String name,
    required String email,
    required String phone,
    required String address,
    required double wallet,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('customers').doc(uid).set({
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'wallet': wallet,
    }, SetOptions(merge: true));
  }

  Future<void> _getCurrentLocation() async {
    final locData = await location.getLocation();
    if (mounted) {
      setState(() {
        currentLatLng = LatLng(locData.latitude!, locData.longitude!);
      });
    }
  }

  Future<void> fetchSuggestions(String input, bool isPickup) async {
    if (input.isEmpty) {
      if (mounted) {
        setState(() {
          if (isPickup) {
            pickupSuggestions = [];
          } else {
            dropoffSuggestions = [];
          }
          isLoadingSuggestions = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() => isLoadingSuggestions = true);
    }

    final url = 'https://nominatim.openstreetmap.org/search?q=$input&format=json&addressdetails=1&limit=5';

    try {
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      if (mounted) {
        setState(() {
          if (isPickup) {
            pickupSuggestions = data;
          } else {
            dropoffSuggestions = data;
          }
          isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingSuggestions = false);
      }
    }
  }

  void onSearchChanged(String input, bool isPickup) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      fetchSuggestions(input, isPickup);
      if (mounted) {
        setState(() {
          if (isPickup) {
            selectedPickup = null;
            showPickupSuggestions = true;
          } else {
            selectedDropoff = null;
            showDropoffSuggestions = true;
          }
        });
      }
    });
  }
  
  // New method to handle selection from suggestions without relying on a tap event
  void handleSuggestionSelection(dynamic suggestion, bool isPickup) {
    if (mounted) {
      setState(() {
        if (isPickup) {
          pickupController.text = suggestion['display_name'];
          selectedPickup = suggestion;
          showPickupSuggestions = false;
          FocusScope.of(context).requestFocus(dropoffFocus);
        } else {
          dropoffController.text = suggestion['display_name'];
          selectedDropoff = suggestion;
          showDropoffSuggestions = false;
          FocusScope.of(context).unfocus();
        }
      });
    }
  }

  Future<LatLng?> getLatLngFromSuggestion(dynamic item) async {
    try {
      final lat = double.tryParse(item['lat'].toString());
      final lon = double.tryParse(item['lon'].toString());
      if (lat != null && lon != null) {
        return LatLng(lat, lon);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> fetchRoutePolyline(LatLng start, LatLng end) async {
    final url = 'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$apiKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}';
    try {
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      if (data['features'] != null && data['features'].isNotEmpty) {
        final coords = data['features'][0]['geometry']['coordinates'] as List;
        if (mounted) {
          setState(() {
            _polylinePoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _polylinePoints = [];
        });
      }
    }
  }

  Future<void> showBoxSelectionAndRoute() async {
    if (selectedPickup == null || selectedDropoff == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select valid suggestions')),
        );
      }
      return;
    }

    final boxResult = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        BoxSize? tempSelectedBox = selectedBox;
        int tempSelectedPrice = selectedBoxPrice;
        String tempSelectedSize = selectedBoxSize;

        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select Box Size', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListTile(
                  leading: Image.asset('assets/images/small.jpg', width: 40),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Small Box'),
                      Radio<BoxSize>(
                        value: BoxSize.small,
                        groupValue: tempSelectedBox,
                        onChanged: (val) {
                          setModalState(() {
                            tempSelectedBox = val;
                            tempSelectedPrice = 500;
                            tempSelectedSize = 'Small';
                          });
                        },
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: Image.asset('assets/images/medium.jpg', width: 40),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Medium Box'),
                      Radio<BoxSize>(
                        value: BoxSize.medium,
                        groupValue: tempSelectedBox,
                        onChanged: (val) {
                          setModalState(() {
                            tempSelectedBox = val;
                            tempSelectedPrice = 1000;
                            tempSelectedSize = 'Medium';
                          });
                        },
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: Image.asset('assets/images/large.jpg', width: 40),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Large Box'),
                      Radio<BoxSize>(
                        value: BoxSize.large,
                        groupValue: tempSelectedBox,
                        onChanged: (val) {
                          setModalState(() {
                            tempSelectedBox = val;
                            tempSelectedPrice = 2000;
                            tempSelectedSize = 'Large';
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: tempSelectedBox != null
                      ? () {
                          Navigator.pop(context, {
                            'box': tempSelectedBox,
                            'price': tempSelectedPrice,
                            'size': tempSelectedSize,
                          });
                        }
                      : null,
                  child: const Text('Confirm Box', style: TextStyle(fontSize: 18, color: Colors.green)),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (boxResult == null || !mounted) return;

    setState(() {
      selectedBox = boxResult['box'] as BoxSize;
      selectedBoxPrice = boxResult['price'] as int;
      selectedBoxSize = boxResult['size'] as String;
    });

    final pickupLatLng = await getLatLngFromSuggestion(selectedPickup);
    final dropoffLatLng = await getLatLngFromSuggestion(selectedDropoff);

    if (pickupLatLng != null && dropoffLatLng != null) {
      await fetchRoutePolyline(pickupLatLng, dropoffLatLng);
      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RouteMapScreen(
            pickup: pickupLatLng,
            dropoff: dropoffLatLng,
            boxLabel: selectedBoxSize,
            boxPrice: selectedBoxPrice,
            pickupAddress: selectedPickup['display_name'],
            dropoffAddress: selectedDropoff['display_name'],
            customerName: profileName,
          ),
        ),
      );
      if (result != null && result is String && mounted) {
        showAgentAssignmentDialog(result);
        setState(() {
          pickupController.clear();
          dropoffController.clear();
          selectedPickup = null;
          selectedDropoff = null;
          selectedBox = null;
          selectedBoxPrice = 0;
          selectedBoxSize = '';
          _polylinePoints = [];
        });
      }
    }
  }

  void showAgentAssignmentDialog(String orderId) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      builder: (_) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final order = snapshot.data!.data() as Map<String, dynamic>?;
            if (order == null) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Order not found.')),
              );
            }
            if (order['status'] == 'accepted') {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 48),
                    const SizedBox(height: 12),
                    Text('Agent ${order['acceptedBy'] ?? ''} has accepted your order!',
                        style: const TextStyle(fontSize: 18, color: Colors.green),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            } else if (order['status'] == 'declined') {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cancel, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    const Text('Sorry, your order was declined by the agent.',
                        style: TextStyle(fontSize: 18, color: Colors.red),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            } else if (order['status'] == 'dropped') {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_shipping, color: Colors.amber, size: 48),
                    const SizedBox(height: 12),
                    const Text('Your package has been delivered by the agent!',
                        style: TextStyle(fontSize: 18, color: Colors.amber),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        await FirebaseFirestore.instance.collection('orders').doc(orderId).update({'status': 'delivered'});
                        final orderSnap = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
                        final orderData = orderSnap.data() as Map<String, dynamic>?;
                        if (orderData != null && orderData['boxPrice'] != null && orderData['acceptedBy'] != null) {
                          final agentEmail = orderData['acceptedBy'];
                          final amount = (orderData['boxPrice'] is int)
                              ? (orderData['boxPrice'] as int).toDouble()
                              : (orderData['boxPrice'] as num).toDouble();
                          final agentDocRef = FirebaseFirestore.instance.collection('agentProfiles').doc(agentEmail);
                          await FirebaseFirestore.instance.runTransaction((transaction) async {
                            final snapshot = await transaction.get(agentDocRef);
                            final currentWallet = (snapshot.data()?['wallet'] ?? 0.0) as num;
                            transaction.update(agentDocRef, {'wallet': currentWallet + amount});
                          });
                        }
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Delivery confirmed!')),
                          );
                        }
                      },
                      child: const Text('Confirm Delivery'),
                    ),
                  ],
                ),
              );
            } else {
              return const Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Waiting for agent to accept your order...',
                        style: TextStyle(fontSize: 18),
                        textAlign: TextAlign.center),
                  ],
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget buildSuggestions(List<dynamic> suggestions, bool isPickup) {
    if (isLoadingSuggestions) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: CircularProgressIndicator(),
      );
    }
    if (suggestions.isEmpty) return const SizedBox();

    return ListView.builder(
      shrinkWrap: true,
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return ListTile(
          title: Text(suggestion['display_name']),
          onTap: () => handleSuggestionSelection(suggestion, isPickup),
        );
      },
    );
  }

  Widget buildMap() {
    return SizedBox(
      height: 300,
      child: currentLatLng == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: MapOptions(
                center: currentLatLng!,
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
                      point: currentLatLng!,
                      child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                    ),
                    if (selectedPickup != null)
                      Marker(
                        point: LatLng(
                          double.tryParse(selectedPickup['lat'].toString()) ?? 0.0,
                          double.tryParse(selectedPickup['lon'].toString()) ?? 0.0,
                        ),
                        child: const Icon(Icons.circle, color: Colors.green, size: 24),
                      ),
                    if (selectedDropoff != null)
                      Marker(
                        point: LatLng(
                          double.tryParse(selectedDropoff['lat'].toString()) ?? 0.0,
                          double.tryParse(selectedDropoff['lon'].toString()) ?? 0.0,
                        ),
                        child: const Icon(Icons.circle, color: Colors.blue, size: 24),
                      ),
                  ],
                ),
                if (_polylinePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _polylinePoints,
                        strokeWidth: 4,
                        color: Colors.blue,
                      ),
                    ],
                  ),
              ],
            ),
    );
  }

  void _onDrawerItemTap(String item) async {
    Navigator.pop(context);
    Widget? screen;
    switch (item) {
      case 'Profile':
        screen = ProfileScreen(
          name: profileName,
          email: profileEmail,
          phone: profilePhone,
          address: profileAddress,
          profileImage: profileImage,
          onProfileUpdated: (name, email, phone, address, image) {
            setState(() {
              profileName = name;
              profileEmail = email;
              profilePhone = phone;
              profileAddress = address;
              profileImage = image;
            });
            _saveProfileToFirestore(
              name: name,
              email: email,
              phone: phone,
              address: address,
              wallet: walletBalance,
            );
          },
        );
        break;
      case 'Messages':
        screen = const MessagesScreen();
        break;
      case 'Notifications':
        screen = const NotificationsScreen();
        break;
      case 'Settings':
        screen = SettingsScreen(
          onThemeChanged: widget.onThemeChanged,
        );
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
      default:
        return;
    }
    if (screen != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
    }
  }

  void _onBottomNavTap(int index) async {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 1) {
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MyRidesScreen()));
      }
    } else if (index == 2) {
      if (mounted) {
        final newBalance = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AccountScreen(
              walletBalance: walletBalance,
              onWalletChanged: (newBalance) async {
                setState(() => walletBalance = newBalance);
              },
            ),
          ),
        );
        if (newBalance != null && mounted) {
          setState(() {
            walletBalance = newBalance as double;
          });
          _saveProfileToFirestore(
            name: profileName,
            email: profileEmail,
            phone: profilePhone,
            address: profileAddress,
            wallet: walletBalance,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color.fromARGB(255, 216, 212, 4)),
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    profileName,
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  const SizedBox(height: 8),
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
                ],
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Pickup Location"),
            TextField(
              controller: pickupController,
              focusNode: pickupFocus,
              decoration: const InputDecoration(hintText: 'Enter pickup'),
              onChanged: (val) => onSearchChanged(val, true),
              onEditingComplete: () {
                if (pickupSuggestions.isNotEmpty) {
                  handleSuggestionSelection(pickupSuggestions[0], true);
                }
              },
            ),
            if (showPickupSuggestions) buildSuggestions(pickupSuggestions, true),
            const SizedBox(height: 16),
            const Text("Drop-off Location"),
            TextField(
              controller: dropoffController,
              focusNode: dropoffFocus,
              decoration: const InputDecoration(hintText: 'Enter drop-off'),
              onChanged: (val) => onSearchChanged(val, false),
              onEditingComplete: () {
                if (dropoffSuggestions.isNotEmpty) {
                  handleSuggestionSelection(dropoffSuggestions[0], false);
                }
              },
            ),
            if (showDropoffSuggestions) buildSuggestions(dropoffSuggestions, false),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (selectedPickup != null && selectedDropoff != null)
                        ? showBoxSelectionAndRoute
                        : null,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color.fromRGBO(255, 251, 3, 0.952)),
                      backgroundColor: const Color.fromARGB(255, 231, 247, 9),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: const Text(
                      'Place Order',
                      style: TextStyle(fontSize: 18, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            buildMap(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home, color: Color.fromARGB(255, 216, 212, 4)),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car, color: Color.fromARGB(255, 216, 212, 4)),
            label: 'My Rides',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle, color: Color.fromARGB(255, 216, 212, 4)),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}