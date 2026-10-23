import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_service.dart';
import '../services/listing_repository.dart';
import '../services/profile_image_service.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  final _imagePicker = ImagePicker();
  final _profileImageService = ProfileImageService();

  String? _profileImageUrl;
  bool _pickingImage = false;
  bool _savingProfile = false;
  bool _changingPassword = false;
  bool _linkingGoogle = false;
  bool _googleLinked = false;
  String? _profileError;
  String? _passwordError;
  String? _linkError;

  @override
  void initState() {
    super.initState();
    final user = _authService.currentUser;
    _usernameController.text = user?.displayName ?? '';
    _googleLinked =
        user?.providerData.any(
          (provider) => provider.providerId == 'google.com',
        ) ??
        false;
    if (user != null) _loadProfileImage(user.uid);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileImage(String userId) async {
    try {
      final url = await _profileImageService.loadUrl(userId);
      if (mounted) setState(() => _profileImageUrl = url);
    } on Exception catch (error) {
      debugPrint('Unable to load profile image: $error');
      if (mounted) {
        setState(
          () => _profileError = 'Could not load your saved profile picture.',
        );
      }
    }
  }

  Future<void> _chooseProfileImage(String userId) async {
    setState(() {
      _pickingImage = true;
      _profileError = null;
    });
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return;
      final url = await _profileImageService.save(userId, image);
      if (mounted) setState(() => _profileImageUrl = url);
    } on Exception catch (error) {
      debugPrint('Unable to select profile image: $error');
      if (mounted) {
        setState(
          () =>
              _profileError = 'Could not save that picture. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _removeProfileImage(String userId) async {
    setState(() {
      _pickingImage = true;
      _profileError = null;
    });
    try {
      await _profileImageService.remove(userId);
      if (mounted) setState(() => _profileImageUrl = null);
    } on Exception catch (error) {
      debugPrint('Unable to remove profile image: $error');
      if (mounted) {
        setState(() => _profileError = 'Could not remove your saved picture.');
      }
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!(_profileFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _savingProfile = true;
      _profileError = null;
    });

    try {
      await _authService.updateProfile(username: _usernameController.text);
      await ListingRepository().syncUserName(_usernameController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile updated.')));
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _profileError = _messageFor(error));
    } on Exception catch (error) {
      debugPrint('Unable to update profile: $error');
      if (mounted) {
        setState(
          () => _profileError =
              'Could not update your profile. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _changingPassword = true;
      _passwordError = null;
    });

    try {
      await _authService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Password changed.')));
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _passwordError = _messageFor(error));
    } on Exception catch (error) {
      debugPrint('Unable to change password: $error');
      if (mounted) {
        setState(
          () => _passwordError =
              'Could not change your password. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  Future<void> _linkGoogleAccount() async {
    setState(() {
      _linkingGoogle = true;
      _linkError = null;
    });

    try {
      final user = await _authService.linkGoogleAccount();
      if (!mounted) return;
      setState(() {
        _googleLinked = user.providerData.any(
          (provider) => provider.providerId == 'google.com',
        );
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Google account linked.')));
    } on GoogleSignInException catch (error) {
      if (!mounted || error.code == GoogleSignInExceptionCode.canceled) return;
      setState(() {
        _linkError =
            error.code == GoogleSignInExceptionCode.clientConfigurationError
            ? 'Google Sign-In is not configured for this app yet.'
            : error.description ?? 'Could not link your Google account.';
      });
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _linkError = _messageFor(error));
    } on Exception catch (error) {
      debugPrint('Unable to link Google account: $error');
      if (mounted) {
        setState(
          () => _linkError =
              'Could not link your Google account. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _linkingGoogle = false);
    }
  }

  String _messageFor(FirebaseAuthException error) => switch (error.code) {
    'wrong-password' ||
    'invalid-credential' => 'Your current password is incorrect.',
    'requires-recent-login' =>
      'Please sign out and sign in again before changing these details.',
    'weak-password' => 'Choose a password with at least 6 characters.',
    'provider-already-linked' => 'A Google account is already linked.',
    'credential-already-in-use' =>
      'That Google account is linked to a different VertivEra account. '
          'Accounts cannot be merged automatically.',
    'too-many-requests' => 'Too many attempts. Please try again later.',
    _ => error.message ?? 'The request failed. Please try again.',
  };

  String? _validateUsername(String? value) {
    final username = value?.trim() ?? '';
    if (username.length < 3 || username.length > 24) {
      return 'Username must be 3 to 24 characters.';
    }
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(username)) {
      return 'Use only letters, numbers, dots, or underscores.';
    }
    return null;
  }

  Widget _profilePreview() {
    return CircleAvatar(
      radius: 42,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      child: _profileImageUrl != null
          ? ClipOval(
              child: Image.network(
                _profileImageUrl!,
                width: 84,
                height: 84,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.person_outline, size: 42),
              ),
            )
          : const Icon(Icons.person_outline, size: 42),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account settings')),
        body: const Center(child: Text('Sign in to manage your account.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Account settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Form(
            key: _profileFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: _profilePreview()),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickingImage
                          ? null
                          : () => _chooseProfileImage(user.uid),
                      icon: _pickingImage
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose picture'),
                    ),
                    if (_profileImageUrl != null)
                      TextButton.icon(
                        onPressed: _pickingImage
                            ? null
                            : () => _removeProfileImage(user.uid),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove'),
                      ),
                  ],
                ),
                const Padding(padding: EdgeInsets.only(top: 4, bottom: 20)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: _validateUsername,
                ),
                const SizedBox(height: 16),
                if (_profileError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _profileError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _savingProfile ? null : _saveProfile,
                  child: _savingProfile
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save profile'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'Sign-in methods',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email and password'),
            subtitle: Text(
              user.providerData.any(
                    (provider) => provider.providerId == 'password',
                  )
                  ? 'Connected'
                  : 'Not connected',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SvgPicture.asset(
              'assets/branding/google_g.svg',
              width: 24,
              height: 24,
              excludeFromSemantics: true,
            ),
            title: const Text('Google'),
            subtitle: Text(_googleLinked ? 'Connected' : 'Not connected'),
          ),
          if (!_googleLinked)
            OutlinedButton.icon(
              onPressed: _linkingGoogle ? null : _linkGoogleAccount,
              icon: _linkingGoogle
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : SvgPicture.asset(
                      'assets/branding/google_g.svg',
                      width: 20,
                      height: 20,
                      excludeFromSemantics: true,
                    ),
              label: Text(
                _linkingGoogle ? 'Connecting…' : 'Link Google account',
              ),
            ),
          if (_linkError != null) ...[
            const SizedBox(height: 8),
            Text(
              _linkError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'Change password',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Form(
            key: _passwordFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) => (value ?? '').isEmpty
                      ? 'Enter your current password.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                  ),
                  validator: (value) => (value ?? '').length < 6
                      ? 'Password must be at least 6 characters.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) => value != _newPasswordController.text
                      ? 'Passwords do not match.'
                      : null,
                ),
                if (_passwordError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _passwordError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: _changingPassword ? null : _changePassword,
                  child: _changingPassword
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update password'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
