import 'package:flutter/material.dart';

import '../models.dart';

class MyListingsPage extends StatelessWidget {
  const MyListingsPage({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('My activity'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Selling'),
            Tab(text: 'Bought'),
            Tab(text: 'Saved'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _list(items.take(2).toList(), 'Active'),
          _list(items.skip(5).take(1).toList(), 'Completed'),
          _list(items.skip(2).take(3).toList(), 'Saved'),
        ],
      ),
    ),
  );
  Widget _list(List<Item> l, String s) => ListView(
    children: l
        .map(
          (i) => ListTile(
            leading: CircleAvatar(
              backgroundColor: i.color,
              child: Icon(i.icon, color: Colors.black54),
            ),
            title: Text(i.title),
            subtitle: Text('RM ${i.price.toStringAsFixed(0)}'),
            trailing: Chip(label: Text(s)),
          ),
        )
        .toList(),
  );
}
