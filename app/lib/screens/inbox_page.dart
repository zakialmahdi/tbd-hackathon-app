import 'package:flutter/material.dart';

import '../services/listing_repository.dart';
import 'chat_page.dart';
import 'item_detail_page.dart';

Future<void> _openListing(BuildContext context, String? listingId) async {
  if (listingId == null || listingId.isEmpty) return;
  final item = await ListingRepository().getListing(listingId);
  if (!context.mounted) return;
  if (item == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This listing is no longer available.')),
    );
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ItemDetailPage(item: item)),
  );
}

void _openOfferChat(BuildContext context, Map<String, dynamic> offer) {
  final listingId = offer['listingId'];
  final buyerId = offer['buyerId'];
  if (listingId is! String || buyerId is! String) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatPage(
        conversationId: '${listingId}_$buyerId',
        title: offer['listingTitle'] as String? ?? 'Listing chat',
      ),
    ),
  );
}

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        bottom: const TabBar(
          tabs: [Tab(text: 'Chats'), Tab(text: 'Offers')],
        ),
      ),
      body: const TabBarView(
        children: [_ChatInbox(), _OfferInbox()],
      ),
    ),
  );
}

class _ChatInbox extends StatelessWidget {
  const _ChatInbox();
  static final _repository = ListingRepository();

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: _repository.watchMyConversations(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text('Could not load chats.\n${snapshot.error}'));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final chats = snapshot.data!;
      if (chats.isEmpty) return const Center(child: Text('No chats yet.'));
      return ListView.builder(
        itemCount: chats.length,
        itemBuilder: (_, index) {
          final chat = chats[index];
          final title = chat['listingTitle'] as String? ?? 'Listing chat';
            final otherName = chat['buyerId'] == _repository.currentUserId
              ? chat['sellerName'] as String? ?? 'Seller'
              : chat['buyerName'] as String? ?? 'Buyer';
            final roleLabel = chat['buyerId'] == _repository.currentUserId
              ? 'Buying from $otherName'
              : 'Selling to $otherName';
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.chat_outlined)),
            title: Text(title),
            subtitle: Text(roleLabel),
            trailing: IconButton(
              tooltip: 'Open chat',
              icon: const Icon(Icons.chat_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    conversationId: chat['id'] as String,
                    title: title,
                  ),
                ),
              ),
            ),
            onTap: () => _openListing(
              context,
              chat['listingId'] as String?,
            ),
          );
        },
      );
    },
  );
}

class _OfferInbox extends StatelessWidget {
  const _OfferInbox();
  static final _repository = ListingRepository();

  Future<void> _accept(BuildContext context, Map<String, dynamic> offer) async {
    try {
      await _repository.acceptOffer(offer);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not accept offer: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: _repository.watchMyOffers(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text('Could not load offers.\n${snapshot.error}'));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final offers = snapshot.data!;
      if (offers.isEmpty) return const Center(child: Text('No offers yet.'));
      return ListView.builder(
        itemCount: offers.length,
        itemBuilder: (_, index) {
          final offer = offers[index];
          final status = offer['status'] as String? ?? 'pending';
          final amount = (offer['amount'] as num?)?.toStringAsFixed(2) ?? '0.00';
          final isSeller = offer['sellerId'] == _repository.currentUserId;
          final otherName = isSeller
              ? offer['buyerName'] as String? ?? 'Buyer'
              : offer['sellerName'] as String? ?? 'Seller';
          return ListTile(
            title: Text(offer['listingTitle'] as String? ?? 'Listing'),
            subtitle: Text('$otherName · RM $amount · $status'),
            trailing: isSeller && status == 'pending'
                ? Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Accept offer',
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _accept(context, offer),
                      ),
                      IconButton(
                        tooltip: 'Reject offer',
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _repository.updateOfferStatus(
                          offer['id'] as String,
                          'rejected',
                        ),
                      ),
                    ],
                  )
                : Chip(label: Text(status)),
            onTap: () => _openOfferChat(context, offer),
          );
        },
      );
    },
  );
}
