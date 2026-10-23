import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';

class ListingRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  ListingRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance,
      _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _listings =>
      _firestore.collection('listings');

  String? get currentUserId => _auth.currentUser?.uid;

  Stream<Map<String, String>> watchConversationNames(String conversationId) =>
      _firestore
          .collection('conversations')
          .doc(conversationId)
          .snapshots()
          .map((snapshot) {
            final data = snapshot.data() ?? const <String, dynamic>{};
            return {
              if (data['buyerId'] is String && data['buyerName'] is String)
                data['buyerId'] as String: data['buyerName'] as String,
              if (data['sellerId'] is String && data['sellerName'] is String)
                data['sellerId'] as String: data['sellerName'] as String,
            };
          });

  Future<void> syncUserName(String name) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    final conversations = await _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .get();
    final offers = await _firestore
        .collection('offers')
        .where('participants', arrayContains: userId)
        .get();
    final batch = _firestore.batch();
    for (final conversation in conversations.docs) {
      batch.update(conversation.reference, {
        conversation.data()['buyerId'] == userId ? 'buyerName' : 'sellerName':
            name,
      });
    }
    for (final offer in offers.docs) {
      batch.update(offer.reference, {
        offer.data()['buyerId'] == userId ? 'buyerName' : 'sellerName': name,
      });
    }
    if (conversations.docs.isNotEmpty || offers.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  Stream<List<Item>> watchActiveListings() => _listings
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map(_sortedItems);

  Future<Item?> getListing(String listingId) async {
    final snapshot = await _listings.doc(listingId).get();
    return snapshot.exists ? Item.fromSnapshot(snapshot) : null;
  }

  Stream<List<Item>> watchMyListings() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(const []);
    return _listings
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map(_sortedItems);
  }

  Stream<List<Item>> watchSavedListings() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(const []);
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('savedListings')
        .snapshots()
        .asyncMap(
          (snapshot) async {
            final result = <Item>[];
            for (final saved in snapshot.docs) {
              final data = saved.data();
              final listingId = data['listingId'];
              if (listingId is! String || listingId.isEmpty) {
                await saved.reference.delete();
                continue;
              }
              final listing = await _listings.doc(listingId).get();
              if (!listing.exists) {
                await saved.reference.delete();
                continue;
              }
              if (listing.data()?['soldTo'] == userId) {
                await saved.reference.delete();
                continue;
              }
              result.add(Item.fromSnapshot(listing));
            }
            return result;
          },
        );
  }

  Future<void> setSaved(Item item, bool saved) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw StateError('You must be signed in to save items.');
    final listingId = item.id.isEmpty
        ? item.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        : item.id;
    final reference = _firestore
        .collection('users')
        .doc(userId)
        .collection('savedListings')
        .doc(listingId);
    if (!saved) {
      await reference.delete();
      return;
    }
    await reference.set({
      'listingId': item.id,
      'title': item.title,
      'category': item.category,
      'condition': item.condition,
      'price': item.price,
      'description': item.desc,
      'seller': item.seller,
      'ownerId': item.ownerId ?? '',
      'status': item.status,
      'distance': item.distance,
      'pickupAddress': item.pickupAddress,
      'imageUrls': item.imageUrls,
      'photoCount': item.imageUrls.length,
    });
  }

  Future<String> openConversation(Item item) async {
    final user = _auth.currentUser;
    if (user == null || item.ownerId == null || item.id.isEmpty) {
      throw StateError('Chat is available for live listings after sign-in.');
    }
    if (item.ownerId == user.uid) {
      throw StateError('You cannot chat with yourself.');
    }
    final conversationId = '${item.id}_${user.uid}';
    final buyerName = user.displayName?.trim().isNotEmpty == true
      ? user.displayName!.trim()
      : user.email ?? 'Buyer';
    await _firestore.collection('conversations').doc(conversationId).set({
      'listingId': item.id,
      'listingTitle': item.title,
      'buyerId': user.uid,
      'sellerId': item.ownerId,
      'buyerName': buyerName,
      'sellerName': item.seller,
      'participants': [user.uid, item.ownerId],
      'status': 'open',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return conversationId;
  }

  Stream<List<Map<String, dynamic>>> watchMessages(String conversationId) =>
      _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('createdAt')
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());

  Stream<bool> watchConversationClosed(String conversationId) => _firestore
      .collection('conversations')
      .doc(conversationId)
      .snapshots()
      .map((snapshot) => snapshot.data()?['status'] == 'closed');

  Stream<List<Item>> watchBoughtListings() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(const []);
    return _listings
        .where('soldTo', isEqualTo: userId)
        .snapshots()
        .map(_sortedItems);
  }

  Stream<List<Map<String, dynamic>>> watchMyConversations() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(const []);
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final chats = snapshot.docs.map((doc) {
            return {'id': doc.id, ...doc.data()};
          }).toList();
          chats.sort((a, b) {
            final aTime = a['updatedAt'] as Timestamp?;
            final bTime = b['updatedAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });
          return chats;
        });
  }

  Stream<List<Map<String, dynamic>>> watchMyOffers() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(const []);
    return _firestore
        .collection('offers')
      .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              return {'id': doc.id, ...doc.data()};
            }).where((offer) => offer['status'] == 'pending').toList());
  }

    Stream<List<Map<String, dynamic>>> watchConversationOffers(
      String conversationId,
    ) {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return Stream.value(const []);
      final listingId = conversationId.split('_').first;
      final buyerId = conversationId.split('_').skip(1).join('_');
      return _firestore
          .collection('offers')
          .where('participants', arrayContains: userId)
          .snapshots()
          .map((snapshot) {
            final offers = snapshot.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .where(
                  (offer) =>
                      offer['listingId'] == listingId &&
                      offer['buyerId'] == buyerId,
                )
                .toList();
            offers.sort((a, b) {
              final aTime = a['createdAt'] as Timestamp?;
              final bTime = b['createdAt'] as Timestamp?;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });
            return offers;
          });
    }

  Future<void> updateOfferStatus(String offerId, String status) async {
    await _firestore.collection('offers').doc(offerId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptOffer(Map<String, dynamic> offer) async {
    final userId = _auth.currentUser?.uid;
    final offerId = offer['id'];
    final listingId = offer['listingId'];
    final buyerId = offer['buyerId'];
    if (userId == null ||
        offerId is! String ||
        listingId is! String ||
        buyerId is! String) {
      throw StateError('This offer is missing required information.');
    }
    if (offer['sellerId'] != userId) {
      throw StateError('Only the seller can accept this offer.');
    }
    final batch = _firestore.batch();
    batch.update(_firestore.collection('offers').doc(offerId), {
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_listings.doc(listingId), {
      'status': 'sold',
      'soldTo': buyerId,
      'soldAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _firestore.collection('conversations').doc('${listingId}_$buyerId'),
      {
        'listingId': listingId,
        'listingTitle': offer['listingTitle'] ?? 'Sold listing',
        'buyerId': buyerId,
        'sellerId': userId,
        'participants': [buyerId, userId],
        'status': 'closed',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      _firestore
          .collection('conversations')
          .doc('${listingId}_$buyerId')
          .collection('messages')
          .doc('sold_notice'),
      {
        'senderId': userId,
        'text': 'This product has been sold. This conversation is now closed.',
        'system': true,
        'createdAt': Timestamp.now(),
      },
    );
    await batch.commit();
  }

  Future<void> sendMessage(String conversationId, String text) async {
    final user = _auth.currentUser;
    if (user == null || text.trim().isEmpty) return;
    final conversation = _firestore
        .collection('conversations')
        .doc(conversationId);
    final conversationData = (await conversation.get()).data() ?? const {};
    final senderName = conversationData['buyerId'] == user.uid
        ? conversationData['buyerName'] as String? ?? user.email ?? 'Buyer'
        : conversationData['sellerName'] as String? ?? user.email ?? 'Seller';
    await conversation.collection('messages').add({
      'senderId': user.uid,
      'senderName': senderName,
      'text': text.trim(),
      'createdAt': Timestamp.now(),
    });
    await conversation.update({'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> createOffer(Item item, double amount) async {
    final user = _auth.currentUser;
    if (user == null || item.ownerId == null || item.id.isEmpty) {
      throw StateError('Offers are available for live listings after sign-in.');
    }
    if (item.ownerId == user.uid) {
      throw StateError('You cannot make an offer on your own listing.');
    }
    final buyerName = user.displayName?.trim().isNotEmpty == true
      ? user.displayName!.trim()
      : user.email ?? 'Buyer';
    await _firestore.collection('offers').add({
      'listingId': item.id,
      'listingTitle': item.title,
      'buyerId': user.uid,
      'sellerId': item.ownerId,
      'buyerName': buyerName,
      'sellerName': item.seller,
      'participants': [user.uid, item.ownerId],
      'amount': amount,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteListing(Item item) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || item.ownerId != userId) {
      throw StateError('You can only delete your own listings.');
    }
    if (item.id.isNotEmpty) {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('savedListings')
          .doc(item.id)
          .delete();
      final folder = _storage.ref('listings/$userId/${item.id}');
      final files = await folder.listAll();
      for (final file in files.items) {
        await file.delete();
      }
      await _listings.doc(item.id).delete();
    }
  }

  List<Item> _sortedItems(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final listings = snapshot.docs.map(Item.fromFirestore).toList();
    listings.sort((a, b) => b.id.compareTo(a.id));
    return listings;
  }

  Future<void> createListing({
    required String title,
    required String category,
    required String condition,
    required double price,
    required String description,
    required String pickupAddress,
    required List<XFile> photos,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You must be signed in to sell an item.');

    final listing = _listings.doc();
    await listing.set({
      'title': title,
      'category': category,
      'condition': condition,
      'price': price,
      'description': description,
      'seller': user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : user.email ?? 'Seller',
      'ownerId': user.uid,
      'status': 'active',
      'distance': 'Pickup nearby',
      'pickupAddress': pickupAddress,
      'imageUrls': const <String>[],
      'photoCount': photos.length,
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      final imageUrls = <String>[];
      for (var index = 0; index < photos.length; index++) {
        final bytes = await photos[index].readAsBytes();
        if (bytes.length > 9 * 1024 * 1024) {
          throw StateError('Each photo must be smaller than 9 MB.');
        }
        final reference = _storage.ref(
          'listings/${user.uid}/${listing.id}/$index.jpg',
        );
        await reference.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        imageUrls.add(await reference.getDownloadURL());
      }
      if (imageUrls.isNotEmpty) {
        await listing.update({'imageUrls': imageUrls});
      }
    } catch (_) {
      await listing.delete();
      rethrow;
    }
  }
}