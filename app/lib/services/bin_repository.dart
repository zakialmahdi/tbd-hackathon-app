import 'package:cloud_firestore/cloud_firestore.dart';

import '../models.dart';

class BinRepository {
  final FirebaseFirestore _firestore;

  BinRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<Bin>> watchBins() {
    return _firestore.collection('bins').snapshots().map((snapshot) {
      final bins = snapshot.docs.map(Bin.fromFirestore).toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      return bins;
    });
  }
}
