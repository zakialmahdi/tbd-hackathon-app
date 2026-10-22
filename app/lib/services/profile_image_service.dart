import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileImageService {
  Future<String?> loadPath(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final path = preferences.getString(_preferenceKey(userId));
    if (path == null || !await File(path).exists()) return null;
    return path;
  }

  Future<String> save(String userId, XFile image) async {
    final directory = await _profileDirectory();
    final extension = _extensionFor(image.path);
    final destination = File(
      '${directory.path}${Platform.pathSeparator}'
      'profile_${_safeUserId(userId)}_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    await File(image.path).copy(destination.path);

    final preferences = await SharedPreferences.getInstance();
    final key = _preferenceKey(userId);
    final previousPath = preferences.getString(key);
    try {
      final saved = await preferences.setString(key, destination.path);
      if (!saved) {
        throw StateError('Could not save the profile image reference.');
      }
    } catch (_) {
      await destination.delete();
      rethrow;
    }

    await _deletePreviousImage(previousPath, directory, userId);
    return destination.path;
  }

  Future<void> remove(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _preferenceKey(userId);
    final previousPath = preferences.getString(key);
    final removed = await preferences.remove(key);
    if (!removed) {
      throw StateError('Could not remove the saved profile image reference.');
    }
    final directory = await _profileDirectory();
    await _deletePreviousImage(previousPath, directory, userId);
  }

  Future<Directory> _profileDirectory() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final directory = Directory(
      '${supportDirectory.path}${Platform.pathSeparator}profile_images',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<void> _deletePreviousImage(
    String? path,
    Directory directory,
    String userId,
  ) async {
    if (path == null) return;
    final file = File(path);
    if (file.parent.path != directory.path ||
        !file.uri.pathSegments.last.startsWith(
          'profile_${_safeUserId(userId)}_',
        )) {
      return;
    }
    if (await file.exists()) await file.delete();
  }

  String _preferenceKey(String userId) => 'profile_image_path_$userId';

  String _safeUserId(String userId) =>
      userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  String _extensionFor(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return 'jpg';
    final extension = path.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,8}$').hasMatch(extension) ? extension : 'jpg';
  }
}
