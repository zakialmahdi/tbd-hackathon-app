import 'package:cloud_firestore/cloud_firestore.dart';

class Co2SavingsService {
  final FirebaseFirestore _firestore;

  Co2SavingsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDocument(String userId) =>
      _firestore.collection('users').doc(userId);

  Stream<double> watchTotalKg(String userId) =>
      _userDocument(userId).snapshots().asyncMap((snapshot) async {
        if (!snapshot.exists) {
          await _firestore.runTransaction((transaction) async {
            final document = await transaction.get(_userDocument(userId));
            if (!document.exists) {
              transaction.set(_userDocument(userId), {'co2SavedKg': 0.0});
            }
          });
          return 0.0;
        }

        final totalKg = snapshot.data()?['co2SavedKg'];
        if (totalKg is! num || !totalKg.isFinite || totalKg < 0) {
          throw FormatException('Invalid CO₂ total in users/$userId: $totalKg');
        }
        return totalKg.toDouble();
      });
}
