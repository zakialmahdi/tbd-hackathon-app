import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../app_config.dart';
import '../models.dart';
import '../services/listing_repository.dart';
import '../shared_widgets.dart';
import 'chat_page.dart';

class ItemDetailPage extends StatefulWidget {
  final Item item;

  const ItemDetailPage({super.key, required this.item});

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  final _repository = ListingRepository();
  bool _busy = false;

  Future<void> _shareListing() async {
    final item = widget.item;
    await Clipboard.setData(
      ClipboardData(
        text: '${item.title} - RM ${item.price.toStringAsFixed(0)}\n'
            'Condition: ${item.condition}\n'
            'Pickup: ${item.pickupAddress}',
      ),
    );
    if (mounted) snack(context, 'Listing details copied to clipboard.');
  }

  Future<void> _reportListing() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Report listing'),
        children: [
          for (final option in [
            'Suspicious or scam listing',
            'Prohibited item',
            'Incorrect information',
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, option),
              child: Text(option),
            ),
        ],
      ),
    );
    if (!mounted || reason == null) return;
    snack(context, 'Report received: $reason');
  }

  Future<void> _chat() async {
    setState(() => _busy = true);
    try {
      final id = await _repository.openConversation(widget.item);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: id,
            title: widget.item.title,
          ),
        ),
      );
    } catch (error) {
      if (mounted) snack(context, '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _offer() async {
    final controller = TextEditingController(
      text: widget.item.price.toStringAsFixed(0),
    );
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make an offer'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: 'RM '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(controller.text.trim()),
            ),
            child: const Text('Send offer'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (amount == null || amount < 0) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await _repository.createOffer(widget.item, amount);
      if (mounted) snack(context, 'Offer sent to the seller.');
    } catch (error) {
      if (mounted) snack(context, '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isSeller = item.ownerId == FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Copy listing details',
            onPressed: _shareListing,
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'Report listing',
            onPressed: _reportListing,
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 260,
            child: item.imageUrls.isEmpty
                ? ColoredBox(
                    color: item.color,
                    child: Icon(item.icon, size: 130, color: Colors.black45),
                  )
                : Image.network(
                    item.imageUrls.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: item.color,
                      child: Icon(item.icon, size: 130, color: Colors.black45),
                    ),
                  ),
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
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text(item.category)),
                    Chip(label: Text('Condition: ${item.condition}')),
                    Chip(
                      avatar: const Icon(Icons.place, size: 16),
                      label: Text(item.pickupAddress),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Description', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(item.desc),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(item.seller),
                    subtitle: const Text('Marketplace seller'),
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
                  onPressed: _busy || isSeller ? null : _chat,
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Chat'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _busy || isSeller ? null : _offer,
                  child: const Text('Buy / Make offer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
