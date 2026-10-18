import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models.dart';
import '../shared_widgets.dart';
import 'item_detail_page.dart';
import 'my_listings_page.dart';
import 'sell_item_page.dart';

class ReMarketPage extends StatefulWidget {
  const ReMarketPage({super.key});
  @override
  State<ReMarketPage> createState() => _ReMarketPageState();
}

class _ReMarketPageState extends State<ReMarketPage> {
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
  final fav = <String>{};

  @override
  Widget build(BuildContext context) {
    final list = items
        .where(
          (i) =>
              (cat == 'All' || i.category == cat) &&
              i.title.toLowerCase().contains(q.toLowerCase()),
        )
        .toList();
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
                      onPressed: () => snack(context, 'No new messages'),
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
                  hintText: 'Search furniture, gadgets, books…',
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
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
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ChoiceChip(
                    label: Text(cats[i]),
                    selected: cat == cats[i],
                    onSelected: (_) => setState(() => cat = cats[i]),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
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
                    children: const [
                      Icon(Icons.eco, color: Colors.white, size: 34),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Every item you reuse saves ~4.2 kg of CO₂. You\'ve saved 38 kg so far!',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
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
  }

  Widget _itemCard(Item it) {
    final isFav = fav.contains(it.title);
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
                    child: Center(
                      child: Icon(it.icon, size: 60, color: Colors.black54),
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
                        onPressed: () => setState(
                          () =>
                              isFav ? fav.remove(it.title) : fav.add(it.title),
                        ),
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
                      Text(
                        ' ${it.distance} · ${it.condition}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
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
}
