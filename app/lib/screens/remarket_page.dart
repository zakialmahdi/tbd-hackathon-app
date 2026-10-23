import 'dart:async';

import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models.dart';
import '../services/auth_service.dart';
import '../services/co2_savings_service.dart';
import '../services/listing_repository.dart';
import '../shared_widgets.dart';
import 'item_detail_page.dart';
import 'inbox_page.dart';
import 'my_listings_page.dart';
import 'sell_item_page.dart';

class ReMarketPage extends StatefulWidget {
  const ReMarketPage({super.key});
  @override
  State<ReMarketPage> createState() => _ReMarketPageState();
}

class _ReMarketPageState extends State<ReMarketPage> {
  late final Stream<double>? _co2SavingsStream;

  static const cats = [
    'All',
    'Furniture',
    'Electronics',
    'Fashion',
    'Books',
    'Home',
    'Sports',
    'Kids',
  ];
  String cat = 'All';
  String q = '';
  String sort = 'Recommended';
  final fav = <String>{};
  final _listingRepository = ListingRepository();
  late final StreamSubscription<List<Item>> _savedSubscription;

  @override
  void initState() {
    super.initState();
    final userId = AuthService().currentUser?.uid;
    _co2SavingsStream = userId == null
        ? null
        : Co2SavingsService().watchTotalKg(userId);
    _savedSubscription = _listingRepository.watchSavedListings().listen((saved) {
      if (!mounted) return;
      setState(() {
        fav
          ..clear()
          ..addAll(saved.map(_itemKey));
      });
    });
  }

  @override
  void dispose() {
    _savedSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Item>>(
      stream: _listingRepository.watchActiveListings(),
      builder: (context, snapshot) {
        final sourceByKey = <String, Item>{};
        for (final item in snapshot.data ?? const <Item>[]) {
          sourceByKey[_itemKey(item)] = item;
        }
        final source = sourceByKey.values.toList();
        final list = source
            .where(
              (i) =>
                  (cat == 'All' || i.category == cat) &&
                  i.title.toLowerCase().contains(q.toLowerCase()),
            )
            .toList();
        list.sort((a, b) => switch (sort) {
          'Price: low to high' => a.price.compareTo(b.price),
          'Price: high to low' => b.price.compareTo(a.price),
          _ => 0,
        });
        return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'remarket-sell-fab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SellItemPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Sell'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ReMarket',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Give pre-loved items a second life',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyListingsPage(),
                        ),
                      ),
                      icon: const Icon(Icons.receipt_long_outlined),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const InboxPage()),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SearchBar(
                  hintText: 'Search furniture, gadgets, books...',
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  trailing: [
                    PopupMenuButton<String>(
                      tooltip: 'Sort listings',
                      initialValue: sort,
                      onSelected: (value) => setState(() => sort = value),
                      icon: const Icon(Icons.tune),
                      itemBuilder: (_) => [
                        'Recommended',
                        'Price: low to high',
                        'Price: high to low',
                      ]
                          .map(
                            (value) => PopupMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  onChanged: (v) => setState(() => q = v),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: cats.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ChoiceChip(
                    label: Text(cats[i]),
                    selected: cat == cats[i],
                    onSelected: (_) => setState(() => cat = cats[i]),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _impactBanner(),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Row(
                  children: [
                    Text(
                      '${list.length} ${list.length == 1 ? 'listing' : 'listings'}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      sort,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _emptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.76,
                  ),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _itemCard(list[i]),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 70)),
          ],
        ),
      ),
        );
      },
    );
  }

  Widget _impactBanner() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B9C5A), Color(0xFF5CC98B)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.eco, color: Colors.white, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: StreamBuilder<double>(
              stream: _co2SavingsStream,
              builder: (context, snapshot) {
                final message = _co2SavingsStream == null
                    ? 'Sign in to see your CO2 saved total.'
                    : snapshot.hasError
                    ? 'Could not load your CO2 saved total.'
                    : !snapshot.hasData
                    ? 'Loading your CO2 saved total...'
                    : 'Every item you reuse saves about 4.2 kg of CO2. '
                          'Your total: ${snapshot.data!.toStringAsFixed(1)} kg.';
                return Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          const Text(
            'No listings found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try another search or category.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => setState(() {
              q = '';
              cat = 'All';
            }),
            child: const Text('Clear filters'),
          ),
        ],
      ),
    ),
  );

  Widget _itemCard(Item it) {
    final isFav = fav.contains(_itemKey(it));
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ItemDetailPage(item: it)),
      ),
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: it.color,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: it.imageUrls.isEmpty
                        ? Center(
                            child: Icon(
                              it.icon,
                              size: 60,
                              color: Colors.black54,
                            ),
                          )
                        : ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: Image.network(
                              it.imageUrls.first,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Center(
                                child: Icon(
                                  it.icon,
                                  size: 60,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.red : Colors.black54,
                        ),
                        onPressed: () => _toggleSaved(it, isFav),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    it.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'RM ${it.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: kGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 13, color: Colors.grey),
                        Expanded(
                          child: Text(
                            ' ${it.distance} · ${it.condition}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _itemKey(Item item) => item.id.isEmpty
      ? item.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
      : item.id;

  Future<void> _toggleSaved(Item item, bool isSaved) async {
    final key = _itemKey(item);
    setState(() => isSaved ? fav.remove(key) : fav.add(key));
    try {
      await _listingRepository.setSaved(item, !isSaved);
    } catch (_) {
      if (mounted) {
        setState(() => isSaved ? fav.add(key) : fav.remove(key));
        snack(context, 'Could not update saved listings.');
      }
    }
  }
}
