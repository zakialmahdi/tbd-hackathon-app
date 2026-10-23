import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'bin_notification_service.dart';
import 'auth_service.dart';
import 'profile_image_service.dart';

class AccountDeletionException implements Exception {
  final String message;

  const AccountDeletionException(this.message);
}

class AccountDeletionService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final BinNotificationService _binNotificationService;
  final ProfileImageService _profileImageService;

  AccountDeletionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    BinNotificationService? binNotificationService,
    ProfileImageService? profileImageService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _binNotificationService =
           binNotificationService ?? BinNotificationService(),
       _profileImageService = profileImageService ?? ProfileImageService();

  Future<void> deleteAccount({
    required String userId,
    required String? password,
    required Future<void> Function() beforeDeletingUserDocument,
    void Function(String progress)? onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != userId) {
      throw const AccountDeletionException(
        'The signed-in user does not match the account.',
      );
    }
    final email = user.email;
    final providers = user.providerData.map((provider) => provider.providerId);
    if (providers.contains('google.com')) {
      await AuthService(auth: _auth).reauthenticateWithGoogle(user);
    } else if (providers.contains('password')) {
      if (email == null || password == null || password.isEmpty) {
        throw const AccountDeletionException(
          'Enter your account password to continue.',
        );
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } else {
      throw const AccountDeletionException(
        'Account deletion is not yet supported for this sign-in method.',
      );
    }

    onProgress?.call('Removing device and profile data…');
    await _runFirebaseStep(
      'Stop this device’s notification tracking',
      _binNotificationService.stopLocalTracking,
    );
    await _runFirebaseStep(
      'Delete your profile picture',
      () => _profileImageService.removeForAccountDeletion(userId),
    );

    final userDocument = _firestore.collection('users').doc(userId);
    onProgress?.call('Removing saved addresses…');
    await _deleteCollection(
      userDocument.collection('savedAddresses'),
      description: 'saved addresses',
    );
    onProgress?.call('Removing notification records…');
    await _deleteCollection(
      userDocument.collection('notificationDevices'),
      description: 'notification records',
    );
    onProgress?.call('Removing account profile…');
    await beforeDeletingUserDocument();
    await _runFirebaseStep('Delete your account data', userDocument.delete);
    try {
      onProgress?.call('Deleting your Firebase Authentication account…');
      await user.delete();
    } on FirebaseAuthException catch (error) {
      final message = error.code == 'requires-recent-login'
          ? 'Firebase Authentication requires a fresh sign-in before it can '
                'delete the account. Sign out, sign back in, and retry.'
          : 'Firebase Authentication could not delete the account '
                '(${error.code}): ${error.message ?? 'Please try again.'}';
      throw AccountDeletionException(message);
    }
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection, {
    required String description,
  }) async {
    while (true) {
      final documents = await _runFirebaseStep(
        'Read $description',
        () => collection.limit(400).get(),
      );
      if (documents.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final document in documents.docs) {
        batch.delete(document.reference);
      }
      await _runFirebaseStep('Delete $description', batch.commit);
    }
  }

  Future<T> _runFirebaseStep<T>(
    String description,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } on FirebaseException catch (error) {
      final message = error.code == 'permission-denied'
          ? '$description was denied by Firebase security rules. Deploy the '
                'latest firestore.rules and storage.rules, then try again.'
          : '$description failed (${error.code}): '
                '${error.message ?? 'Please try again.'}';
      throw AccountDeletionException(message);
    }
  }
}
