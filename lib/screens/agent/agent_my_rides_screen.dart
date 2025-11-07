import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'agent_order_screen.dart';

class AgentMyRidesScreen extends StatefulWidget {
  const AgentMyRidesScreen({super.key});

  @override
  State<AgentMyRidesScreen> createState() => _AgentMyRidesScreenState();
}

class _AgentMyRidesScreenState extends State<AgentMyRidesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Add a listener to rebuild the widget when the tab changes
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Deliveries'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (index) {
              final tabs = ['Current', 'Pending', 'Past'];
              final isSelected = _tabController.index == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () => _tabController.animateTo(index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.yellow[400] : Colors.white,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      tabs[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || uid == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;

          List<QueryDocumentSnapshot> currentOrders = [];
          List<QueryDocumentSnapshot> pendingOrders = [];
          List<QueryDocumentSnapshot> pastOrders = [];

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status'] ?? '').toString().toLowerCase();
            final acceptedById = data['acceptedById'] ?? '';
            final declinedBy = (data['declinedBy'] ?? []) as List<dynamic>;

            if (status == 'accepted' && acceptedById == uid) {
              currentOrders.add(doc);
            } else if (status == 'pending' &&
                !declinedBy.map((e) => e.toString()).contains(uid) &&
                (acceptedById == '' || acceptedById == null)) {
              pendingOrders.add(doc);
            } else if (declinedBy.map((e) => e.toString()).contains(uid) ||
                status == 'dropped' ||
                status == 'cancelled') {
              pastOrders.add(doc);
            }
          }

          return TabBarView(
            controller: _tabController,
            children: [
              // Current Orders List
              currentOrders.isEmpty
                  ? const Center(child: Text('No current orders.'))
                  : ListView(
                      children: currentOrders.map((doc) {
                        final order = doc.data() as Map<String, dynamic>;
                        final docId = doc.id;
                        return Card(
                          child: ListTile(
                            title: Text('${order['pickupAddress']} → ${order['dropoffAddress']}'),
                            subtitle: Text('Status: ${order['status']}'),
                            trailing: const Icon(Icons.arrow_forward),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AgentOrderScreen(orderId: docId),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),

              // Pending Orders List
              pendingOrders.isEmpty
                  ? const Center(child: Text('No pending orders.'))
                  : ListView(
                      children: pendingOrders.map((doc) {
                        final order = doc.data() as Map<String, dynamic>;
                        final docId = doc.id;
                        return Card(
                          child: ListTile(
                            title: Text('${order['pickupAddress']} → ${order['dropoffAddress']}'),
                            subtitle: Text('Box: ${order['boxLabel']} | ₦${order['boxPrice']}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance.collection('orders').doc(docId).update({
                                      'status': 'accepted',
                                      'acceptedById': uid,
                                      'acceptedBy': FirebaseAuth.instance.currentUser?.email,
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance.collection('orders').doc(docId).update({
                                      'declinedBy': FieldValue.arrayUnion([uid]),
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

              // Past Orders List
              pastOrders.isEmpty
                  ? const Center(child: Text('No past orders.'))
                  : ListView(
                      children: pastOrders.map((doc) {
                        final order = doc.data() as Map<String, dynamic>;
                        final docId = doc.id;
                        return Card(
                          color: Colors.grey[100],
                          child: ListTile(
                            title: Text('${order['pickupAddress']} → ${order['dropoffAddress']}'),
                            subtitle: Text('Status: ${order['status']}'),
                            trailing: const Icon(Icons.history),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AgentOrderScreen(orderId: docId),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),
            ],
          );
        },
      ),
    );
  }
}