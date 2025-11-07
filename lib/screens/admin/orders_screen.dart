import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildOrderList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          switch (status) {
            case 'current':
              return data['status'] == 'accepted' ;
            case 'pending':
              return data['status'] == 'pending';
            case 'past':
              return data['status'] == 'delivered' || data['status'] == 'dropped';
            case 'cancel':
              return data['status'] == 'cancelled' || data['status'] == 'declined';
            default:
              return false;
          }
        }).toList();

        if (docs.isEmpty) {
          return Center(child: Text('No $status orders.'));
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final order = docs[i].data() as Map<String, dynamic>;
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
                              : Icons.cancel,
                  color: status == 'current'
                      ? Colors.green
                      : status == 'pending'
                          ? Colors.amber
                          : status == 'past'
                              ? Colors.blueGrey
                              : Colors.red,
                ),
                title: Text('${order['pickupAddress']} → ${order['dropoffAddress']}'),
                subtitle: Text(
                    'Box: ${order['boxLabel']} | Status: ${order['status']} | ₦${order['boxPrice']}'),
                trailing: Text(
                  order['createdAt'] != null
                      ? (order['createdAt'] as Timestamp).toDate().toLocal().toString().split('.')[0]
                      : '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
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
        title: const Text('Orders'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Current'),
            Tab(text: 'Pending'),
            Tab(text: 'Past'),
            Tab(text: 'Cancel'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList('current'),
          _buildOrderList('pending'),
          _buildOrderList('past'),
          _buildOrderList('cancel'),
        ],
      ),
    );
  }
}