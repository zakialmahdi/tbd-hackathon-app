import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/listing_repository.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String title;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.title,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _repository = ListingRepository();
  final _controller = TextEditingController();
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  late final StreamSubscription<Map<String, String>> _nameSubscription;
  Map<String, String> _participantNames = const {};
  late final StreamSubscription<bool> _closedSubscription;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _closedSubscription = _repository
        .watchConversationClosed(widget.conversationId)
        .listen((closed) {
          if (mounted) setState(() => _closed = closed);
        });
    _nameSubscription = _repository
        .watchConversationNames(widget.conversationId)
        .listen((names) {
          if (mounted) setState(() => _participantNames = names);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    _closedSubscription.cancel();
    _nameSubscription.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    if (_closed) return;
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    try {
      await _repository.sendMessage(widget.conversationId, text);
      if (mounted) _controller.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send message: $error')),
        );
      }
    }
  }

  Future<void> _acceptOffer(Map<String, dynamic> offer) async {
    try {
      await _repository.acceptOffer(offer);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not accept offer: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Column(
      children: [
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _repository.watchMessages(widget.conversationId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Could not load messages.\n${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
                final messages = snapshot.data!
                  .where((message) => message['system'] != true)
                  .toList();
              if (messages.isEmpty) {
                return const Center(child: Text('Start the conversation.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (_, index) {
                  final message = messages[index];
                  final isMine = message['senderId'] == _currentUserId;
                    final isSystem = message['system'] == true;
                  return Align(
                    alignment: isSystem
                      ? Alignment.center
                      : isMine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                        color: isSystem
                          ? Theme.of(context).colorScheme.tertiaryContainer
                          : isMine
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: isSystem || isMine
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (!isSystem)
                            Text(
                            isMine
                              ? FirebaseAuth.instance.currentUser?.displayName ??
                                'You'
                              : _participantNames[message['senderId']] ??
                                message['senderName'] as String? ??
                                'Participant',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        Text(message['text'] as String? ?? ''),
                      ],
                    ),
                  ),
                );
                },
              );
            },
          ),
        ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _repository.watchConversationOffers(widget.conversationId),
          builder: (context, snapshot) {
            final offers = snapshot.data ?? const <Map<String, dynamic>>[];
            if (offers.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 156,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                scrollDirection: Axis.horizontal,
                itemCount: offers.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) => _OfferCard(
                  offer: offers[index],
                  isSeller: offers[index]['sellerId'] ==
                      _repository.currentUserId,
                  onAccept: () => _acceptOffer(offers[index]),
                  onReject: () => _repository.updateOfferStatus(
                    offers[index]['id'] as String,
                    'rejected',
                  ),
                ),
              ),
            );
          },
        ),
        SafeArea(
          child: _closed
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Text(
                    'This product has been sold. Chat is closed.',
                    textAlign: TextAlign.center,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Message seller',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Send message',
                        onPressed: _send,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    ),
  );
}

class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final bool isSeller;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _OfferCard({
    required this.offer,
    required this.isSeller,
    required this.onAccept,
    required this.onReject,
  });

  String _time(dynamic value) {
    if (value is! Timestamp) return 'Time unavailable';
    final date = value.toDate().toLocal();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'AM' : 'PM';
    return '${date.day}/${date.month} $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final status = offer['status'] as String? ?? 'pending';
    final amount = (offer['amount'] as num?)?.toStringAsFixed(2) ?? '0.00';
    final statusColor = switch (status) {
      'accepted' => Colors.green,
      'rejected' => Colors.red,
      _ => Theme.of(context).colorScheme.secondary,
    };
    return Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Offer: RM $amount',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Chip(
                label: Text(status),
                labelStyle: TextStyle(color: statusColor),
                side: BorderSide(color: statusColor),
              ),
            ],
          ),
          Text(_time(offer['createdAt']), style: const TextStyle(fontSize: 11)),
          if (isSeller && status == 'pending')
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                  IconButton(
                    tooltip: 'Reject offer',
                    onPressed: onReject,
                    icon: const Icon(Icons.close, color: Colors.red),
                  ),
                  IconButton(
                    tooltip: 'Accept offer',
                    onPressed: onAccept,
                    icon: const Icon(Icons.check, color: Colors.green),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}