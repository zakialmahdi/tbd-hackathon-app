import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models.dart';
import '../shared_widgets.dart';

class ItemDetailPage extends StatelessWidget {
  final Item item;
  const ItemDetailPage({super.key, required this.item});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      actions: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
        IconButton(onPressed: () {}, icon: const Icon(Icons.flag_outlined)),
      ],
    ),
    body: ListView(
      children: [
        Container(
          height: 260,
          color: item.color,
          child: Icon(item.icon, size: 130, color: Colors.black45),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RM ${item.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: kGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(item.category)),
                  Chip(label: Text('Condition: ${item.condition}')),
                  Chip(
                    avatar: const Icon(Icons.place, size: 16),
                    label: Text(item.distance),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(item.desc),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(item.seller),
                  subtitle: const Text('★ 4.8 · 23 items sold'),
                  trailing: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Profile'),
                  ),
                ),
              ),
              Card(
                color: kGreen.withOpacity(0.1),
                child: const ListTile(
                  leading: Icon(Icons.eco, color: kGreen),
                  title: Text('Eco impact'),
                  subtitle: Text('Buying this saves approx. 6.5 kg CO₂'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => snack(context, 'Chat opened'),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Chat'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: () => snack(context, 'Offer sent to seller'),
                child: const Text('Buy / Make offer'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
