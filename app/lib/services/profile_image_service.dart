import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileImageService {
  static const _legacyPathKeyPrefix = 'profile_image_path_';

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  ProfileImageService({FirebaseAuth? auth, FirebaseStorage? storage})
    : _auth = auth ?? FirebaseAuth.instance,
      _storage = storage ?? FirebaseStorage.instance;

  Future<String?> loadUrl(String userId) async {
    final user = _auth.currentUser;
    if (user?.uid != userId) return null;
    final existingUrl = user?.photoURL;
    if (existingUrl != null && existingUrl.isNotEmpty) return existingUrl;

    final preferences = await SharedPreferences.getInstance();
    final legacyPath = preferences.getString('$_legacyPathKeyPrefix$userId');
    if (legacyPath == null) return null;

    final legacyFile = File(legacyPath);
    if (!await legacyFile.exists()) {
      await preferences.remove('$_legacyPathKeyPrefix$userId');
      return null;
    }

    final downloadUrl = await save(userId, XFile(legacyPath));
    await preferences.remove('$_legacyPathKeyPrefix$userId');
    if (_isLegacyProfileFile(userId, legacyFile.path)) {
      try {
        await legacyFile.delete();
      } on FileSystemException catch (error) {
        debugPrint('Could not remove migrated local profile image: $error');
      }
    }
    return downloadUrl;
  }

  Future<String> save(String userId, XFile image) async {
    final user = _requireUser(userId);
    final file = File(image.path);
    if (!await file.exists()) {
      throw StateError('The selected profile image is no longer available.');
    }
    final size = await file.length();
    if (size == 0 || size > 5 * 1024 * 1024) {
      throw StateError('Choose an image smaller than 5 MB.');
    }

    final extension = _extensionFor(image.path);
    final contentType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      _ => throw StateError('Choose a JPEG, PNG, WebP, GIF, or HEIC image.'),
    };
    final reference = _storage
        .ref()
        .child('profilePictures')
        .child(userId)
        .child('${DateTime.now().microsecondsSinceEpoch}.$extension');

    final previousUrl = user.photoURL;
    await reference.putFile(file, SettableMetadata(contentType: contentType));
    final downloadUrl = await reference.getDownloadURL();
    try {
      if (_auth.currentUser?.uid != userId) {
        throw StateError('The signed-in account changed during image upload.');
      }
      await user.updatePhotoURL(downloadUrl);
    } catch (_) {
      await reference.delete();
      rethrow;
    }

    await _deletePreviousImage(
      userId,
      previousUrl,
      exceptPath: reference.fullPath,
    );
    return downloadUrl;
  }

  Future<void> remove(String userId) async {
    final user = _requireUser(userId);
    final previousUrl = user.photoURL;
    await user.updatePhotoURL(null);
    await _deletePreviousImage(userId, previousUrl);
  }

  Future<void> removeForAccountDeletion(String userId) async {
    final user = _requireUser(userId);
    final previousUrl = user.photoURL;
    if (previousUrl != null && previousUrl.isNotEmpty) {
      try {
        final reference = _storage.refFromURL(previousUrl);
        if (reference.fullPath.startsWith('profilePictures/$userId/')) {
          try {
            await reference.delete();
          } on FirebaseException catch (error) {
            if (error.code != 'object-not-found') rethrow;
          }
        }
      } on ArgumentError {
        // The profile URL is not a Firebase Storage object owned by the app.
      } on AssertionError catch (error) {
        // refFromURL asserts when a non-Storage URL cannot be parsed.
        debugPrint('Profile image URL is not a Storage URL: $error');
      }
    }
    await user.updatePhotoURL(null);

    final preferences = await SharedPreferences.getInstance();
    final legacyPath = preferences.getString('$_legacyPathKeyPrefix$userId');
    if (legacyPath != null && _isLegacyProfileFile(userId, legacyPath)) {
      final file = File(legacyPath);
      if (await file.exists()) await file.delete();
    }
    await preferences.remove('$_legacyPathKeyPrefix$userId');
  }

  User _requireUser(String userId) {
    final user = _auth.currentUser;
    if (user == null || user.uid != userId) {
      throw StateError('The signed-in user does not match the profile.');
    }
    return user;
  }

  bool _isLegacyProfileFile(String userId, String path) {
    final file = File(path);
    final safeUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return file.parent.path.endsWith(
          '${Platform.pathSeparator}profile_images',
        ) &&
        file.uri.pathSegments.last.startsWith('profile_${safeUserId}_');
  }

  Future<void> _deletePreviousImage(
    String userId,
    String? url, {
    String? exceptPath,
  }) async {
    if (url == null || url.isEmpty) return;
    try {
      final reference = _storage.refFromURL(url);
      if (!reference.fullPath.startsWith('profilePictures/$userId/')) return;
      if (reference.fullPath == exceptPath) return;
      await reference.delete();
    } on FirebaseException catch (error) {
      debugPrint('Could not delete previous profile image: $error');
    } on ArgumentError catch (error) {
      debugPrint('Previous profile image URL is not a Storage URL: $error');
    } on AssertionError catch (error) {
      debugPrint('Previous profile image URL is not a Storage URL: $error');
    }
  }

  String _extensionFor(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return 'jpg';
    final extension = path.substring(dot + 1).toLowerCase();
    if (!const {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
      'heic',
    }.contains(extension)) {
      throw StateError('Choose a JPEG, PNG, WebP, GIF, or HEIC image.');
    }
    return extension;
  }
}
