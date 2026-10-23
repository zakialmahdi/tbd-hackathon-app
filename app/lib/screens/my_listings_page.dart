import 'package:flutter/material.dart';

import '../models.dart';
import '../services/listing_repository.dart';
import 'item_detail_page.dart';

class MyListingsPage extends StatelessWidget {
  const MyListingsPage({super.key});
  static final _listingRepository = ListingRepository();

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
          StreamBuilder<List<Item>>(
            stream: _listingRepository.watchMyListings(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load your listings.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _list(context, snapshot.data!, 'Active');
            },
          ),
          StreamBuilder<List<Item>>(
            stream: _listingRepository.watchBoughtListings(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Could not load bought listings.\n${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _list(context, snapshot.data!, 'Bought');
            },
          ),
          StreamBuilder<List<Item>>(
            stream: _listingRepository.watchSavedListings(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Could not load saved listings.\n${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _list(context, snapshot.data!, 'Saved');
            },
          ),
        ],
      ),
    ),
  );

  Widget _list(BuildContext context, List<Item> l, String s) => ListView(
    children: l.isEmpty
        ? [const Center(child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('You have not posted any listings yet.'),
          ))]
        : l
              .map(
                (i) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: i.color,
                    child: Icon(i.icon, color: Colors.black54),
                  ),
                  title: Text(i.title),
                  subtitle: Text('RM ${i.price.toStringAsFixed(0)}'),
                  onTap: s == 'Saved' || s == 'Active' || s == 'Bought'
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ItemDetailPage(item: i),
                          ),
                        )
                      : null,
                      trailing: s == 'Active' && i.status != 'sold'
                      ? IconButton(
                          tooltip: 'Delete listing',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDelete(context, i),
                        )
                      : Chip(
                          label: Text(
                            s == 'Bought'
                                ? 'Purchased'
                                : i.status == 'sold'
                                ? 'Sold'
                                : 'Saved',
                          ),
                        ),
                ),
              )
              .toList(),
  );

  Future<void> _confirmDelete(BuildContext context, Item item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete listing?'),
        content: Text('Remove "${item.title}" from ReMarket?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _listingRepository.deleteListing(item);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete listing: $error')),
        );
      }
    }
  }
}
