import 'package:cloud_firestore/cloud_firestore.dart';

class SavedAddress {
  final String id;
  final String address;
  final GeoPoint location;
  final DateTime createdAt;

  const SavedAddress({
    required this.id,
    required this.address,
    required this.location,
    required this.createdAt,
  });

  factory SavedAddress.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final address = data['address'];
    final location = data['location'];
    final createdAt = data['createdAt'];
    if (address is! String ||
        address.trim().isEmpty ||
        location is! GeoPoint ||
        createdAt is! Timestamp) {
      throw FormatException('Saved address ${document.id} has invalid fields.');
    }

    return SavedAddress(
      id: document.id,
      address: address,
      location: location,
      createdAt: createdAt.toDate(),
    );
  }
}

class SavedAddressService {
  final FirebaseFirestore _firestore;

  SavedAddressService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _addresses(String userId) =>
      _firestore.collection('users').doc(userId).collection('savedAddresses');

  Stream<List<SavedAddress>> watchAddresses(String userId) {
    return _addresses(userId).snapshots().map((snapshot) {
      final addresses = snapshot.docs.map(SavedAddress.fromFirestore).toList();
      addresses.sort(
        (first, second) => second.createdAt.compareTo(first.createdAt),
      );
      return addresses;
    });
  }

  Future<void> addAddress(
    String userId, {
    required String address,
    required GeoPoint location,
  }) {
    return _addresses(userId).add({
      'address': address.trim(),
      'location': location,
      'createdAt': Timestamp.now(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAddress(
    String userId, {
    required String addressId,
    required String address,
    required GeoPoint location,
  }) {
    return _addresses(userId).doc(addressId).update({
      'address': address.trim(),
      'location': location,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAddress(String userId, String addressId) {
    return _addresses(userId).doc(addressId).delete();
  }
}
