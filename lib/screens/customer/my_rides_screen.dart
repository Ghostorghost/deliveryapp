import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'track_order_screen.dart';

class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({super.key});

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? userRole;
  String? userEmail;
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _fetchUserInfo();
  }

  Future<void> _fetchUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userEmail = user.email;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.email).get();
      setState(() {
        userRole = userDoc.data()?['role'] ?? 'customer';
        _loadingUser = false;
      });
    } else {
      setState(() {
        userRole = null;
        userEmail = null;
        _loadingUser = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildOrderList(String status) {
    if (_loadingUser) {
      return const Center(child: CircularProgressIndicator());
    }
    if (userRole == null) {
      return const Center(child: Text('Not logged in.'));
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('User ID not available.'));
    }

    Query ordersQuery = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('createdAt', descending: true);

    if (userRole == 'customer') {
      ordersQuery = ordersQuery.where('customerId', isEqualTo: uid);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: ordersQuery.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        List<QueryDocumentSnapshot> docs = snapshot.data!.docs;

        // Filter orders based on status, except for 'history'
        if (status != 'history') {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final s = data['status'];
            final acceptedById = data['acceptedById'] ?? '';
            final customerId = data['customerId'] ?? '';
            final declinedBy = (data['declinedBy'] ?? []) as List<dynamic>;

            if (status == 'current') {
              if (userRole == 'agent') {
                return s == 'accepted' && acceptedById == uid;
              } else if (userRole == 'customer') {
                return s == 'accepted' && customerId == uid;
              } else {
                return s == 'accepted';
              }
            } else if (status == 'pending') {
              if (userRole == 'agent') {
                return s == 'pending' && !declinedBy.contains(uid) && (acceptedById == '' || acceptedById == null);
              } else if (userRole == 'customer') {
                return s == 'pending' && customerId == uid;
              } else {
                return s == 'pending';
              }
            } else if (status == 'past') {
              if (userRole == 'agent') {
                return declinedBy.contains(uid) || s == 'dropped' || s == 'cancelled';
              } else if (userRole == 'customer') {
                return (s == 'dropped' || s == 'cancelled') && customerId == uid;
              } else {
                return s == 'dropped' || s == 'cancelled';
              }
            }
            return false;
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(child: Text('No $status orders.'));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final order = docs[i].data() as Map<String, dynamic>;
            final docId = docs[i].id;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: Icon(
                  status == 'current'
                      ? Icons.local_shipping
                      : status == 'pending'
                          ? Icons.hourglass_top
                          : status == 'past'
                              ? Icons.history
                              : Icons.receipt_long,
                  color: status == 'current'
                      ? Colors.green
                      : status == 'pending'
                          ? Colors.amber
                          : status == 'past'
                              ? Colors.grey
                              : Colors.blueGrey,
                ),
                title: Text('${order['pickupAddress']} → ${order['dropoffAddress']}'),
                subtitle: Text(
                  'Box: ${order['boxLabel']} | Status: ${order['status']} | ₦${order['boxPrice']}',
                ),
                onTap: () async {
                  // Existing tracking for current orders
                  if (status == 'current') {
                    if (order['pickup'] != null && order['dropoff'] != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TrackOrderScreen(order: {
                            ...order,
                            'acceptedBy': order['acceptedBy'],
                            'pickup': order['pickup'],
                            'dropoff': order['dropoff'],
                          }),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tracking information unavailable.')),
                      );
                    }
                  }
                  // New: Confirm and pay for dropped orders in "past" tab
                  else if (status == 'past' && order['status'] == 'dropped') {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirm Delivery'),
                        content: const Text('Did you receive your package?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('No'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Yes, Received'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      // Payment logic: always pay, regardless of payment method
                      final customerId = order['customerId'];
                      final agentId = order['acceptedById'];
                      final price = (order['boxPrice'] as num).toDouble();

                      final usersRef = FirebaseFirestore.instance.collection('users');
                      final customerDoc = await usersRef.doc(customerId).get();
                      final agentDoc = await usersRef.doc(agentId).get();

                      final customerWallet = (customerDoc.data()?['wallet'] ?? 0).toDouble();
                      final agentWallet = (agentDoc.data()?['wallet'] ?? 0).toDouble();

                      if (customerWallet >= price) {
                        await usersRef.doc(customerId).update({'wallet': customerWallet - price});
                        await usersRef.doc(agentId).update({'wallet': agentWallet + price});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Payment successful!')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Insufficient wallet balance!')),
                        );
                        return;
                      }
                      // Mark order as completed
                      await FirebaseFirestore.instance.collection('orders').doc(docId).update({
                        'status': 'completed',
                        'completedAt': FieldValue.serverTimestamp(),
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Order confirmed as received!')),
                      );
                    }
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rides'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (index) {
              final tabs = ['Current', 'Pending', 'Past', 'History'];
              final isSelected = _tabController.index == index;

              return GestureDetector(
                onTap: () => _tabController.animateTo(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.yellow[400] : Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    tabs[index],
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList('current'),
          _buildOrderList('pending'),
          _buildOrderList('past'),
          _buildOrderList('history'),
        ],
      ),
    );
  }
}