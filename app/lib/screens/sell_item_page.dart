import 'package:flutter/material.dart';

import '../app_config.dart';
import '../shared_widgets.dart';

class SellItemPage extends StatefulWidget {
  const SellItemPage({super.key});
  @override
  State<SellItemPage> createState() => _SellItemPageState();
}

class _SellItemPageState extends State<SellItemPage> {
  String cond = 'Good';
  String cat = 'Furniture';
  bool free = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sell an item')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              InkWell(
                onTap: () {},
                child: Container(
                  width: 90,
                  decoration: BoxDecoration(
                    border: Border.all(color: kGreen),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add_a_photo_outlined, color: kGreen),
                      SizedBox(height: 4),
                      Text('Add photo', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const TextField(decoration: InputDecoration(labelText: 'Title')),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: cat,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            'Furniture',
            'Electronics',
            'Fashion',
            'Books',
            'Home',
            'Sports',
            'Kids',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => cat = v!),
        ),
        const SizedBox(height: 14),
        const Text('Condition', style: TextStyle(fontWeight: FontWeight.w600)),
        Wrap(
          spacing: 8,
          children: ['New', 'Like new', 'Good', 'Fair']
              .map(
                (c) => ChoiceChip(
                  label: Text(c),
                  selected: cond == c,
                  onSelected: (_) => setState(() => cond = c),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Give away for free'),
          subtitle: const Text('Earn double eco points'),
          value: free,
          onChanged: (v) => setState(() => free = v),
        ),
        if (!free)
          const TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Price', prefixText: 'RM '),
          ),
        const SizedBox(height: 14),
        const TextField(
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Description',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 14),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.place_outlined),
          title: Text('Pickup location'),
          subtitle: Text('Taman Sri Kajang, Selangor'),
          trailing: Icon(Icons.chevron_right),
        ),
        const SizedBox(height: 10),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          onPressed: () {
            Navigator.pop(context);
            snack(context, 'Listing posted!');
          },
          child: const Text('Post listing'),
        ),
      ],
    ),
  );
}
