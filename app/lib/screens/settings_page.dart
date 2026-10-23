import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';
import '../services/account_deletion_service.dart';
import '../services/auth_service.dart';
import '../services/co2_savings_service.dart';
import '../services/profile_image_service.dart';
import '../services/bin_notification_service.dart';
import '../shared_widgets.dart';
import 'about_vertivera_page.dart';
import 'account_settings_page.dart';
import 'account_deletion_password_page.dart';
import 'payment_methods_page.dart';
import 'pickup_history_page.dart';
import 'rewards_vouchers_page.dart';
import 'saved_addresses_page.dart';

class SettingsPage extends StatefulWidget {
  final Stream<User?>? authStateChanges;

  const SettingsPage({super.key, this.authStateChanges});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Stream<User?> _authStateChanges =
      widget.authStateChanges ?? AuthService().userChanges;
  final _profileImageService = ProfileImageService();
  final _co2SavingsService = Co2SavingsService();
  final _binNotificationService = BinNotificationService();
  late final _accountDeletionService = AccountDeletionService(
    binNotificationService: _binNotificationService,
    profileImageService: _profileImageService,
  );

  bool notif = false, binAlert = false;
  bool _notificationSettingsLoading = false;
  bool _savingNotificationSettings = false;
  bool _deletingAccount = false;
  String? _accountDeletionStatus;
  String? _accountDeletionError;
  String? _notificationUserId;
  String get lang => languageName(appLocale.value);
  String? _profileImageUrl;
  String? _loadedProfileUserId;
  String? _co2SavingsUserId;
  Stream<double>? _co2SavingsStream;

  Future<void> _signOut() async {
    try {
      final userId = AuthService().currentUser?.uid;
      if (userId != null) {
        await _binNotificationService.stopForSignOut(userId);
      }
      await AuthService().signOut();
    } on Exception catch (error) {
      debugPrint('Unable to sign out: $error');
      if (mounted) snack(context, 'Could not sign out. Please try again.');
    }
  }

  Future<void> _selectLanguage(Locale locale) async {
    appLocale.value = locale;
    setState(() {});
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('app_language', locale.languageCode);
  }

  Future<void> _confirmDeleteAccount(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const AccountDeletionConfirmationDialog(),
    );
    if (confirmed != true || !mounted) return;

    final usesGoogle = user.providerData.any(
      (provider) => provider.providerId == 'google.com',
    );
    final usesPassword = user.providerData.any(
      (provider) => provider.providerId == 'password',
    );
    String? password;
    if (usesPassword && !usesGoogle) {
      password = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          builder: (_) => const AccountDeletionPasswordPage(),
        ),
      );
      if (password == null || !mounted) return;
    } else if (!usesGoogle && !usesPassword) {
      snack(
        context,
        'Account deletion is not available for this sign-in method.',
      );
      return;
    }

    setState(() {
      _deletingAccount = true;
      _accountDeletionStatus = 'Verifying your Google account…';
      _accountDeletionError = null;
    });
    try {
      await _accountDeletionService.deleteAccount(
        userId: user.uid,
        password: password,
        onProgress: (progress) {
          if (mounted) setState(() => _accountDeletionStatus = progress);
        },
        beforeDeletingUserDocument: () async {
          if (!mounted) return;
          setState(() => _co2SavingsStream = null);
          await WidgetsBinding.instance.endOfFrame;
        },
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        if (mounted) {
          await _setAccountDeletionError(
            'Google verification was cancelled. Account not deleted.',
          );
        }
      } else {
        debugPrint('Unable to verify Google account for deletion: $error');
        if (mounted) {
          await _setAccountDeletionError(
            error.description ?? 'Could not verify your Google account.',
          );
        }
      }
    } on FirebaseAuthException catch (error) {
      debugPrint('Unable to delete account: $error');
      if (mounted) {
        await _setAccountDeletionError(
          'Account deletion failed while '
          '${_accountDeletionStatus?.toLowerCase() ?? 'verifying your account'}: '
          '${_accountDeletionAuthMessage(error, usesGoogle)}',
        );
      }
    } on StateError catch (error, stackTrace) {
      debugPrint(
        'Google account verification stopped unexpectedly: $error\n$stackTrace',
      );
      if (mounted) {
        final message = error.message.contains('ID token')
            ? 'Google verification did not return an ID token. Check that '
                  'google-services.json is current, includes the Web OAuth '
                  'client, and matches this app’s signing SHA-1.'
            : 'Google verification could not complete: ${error.message}';
        await _setAccountDeletionError(message);
      }
    } on AccountDeletionException catch (error) {
      debugPrint('Unable to complete account deletion: ${error.message}');
      if (mounted) {
        await _setAccountDeletionError(
          'Account deletion failed while '
          '${_accountDeletionStatus?.toLowerCase() ?? 'preparing'}: '
          '${error.message}',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to complete account deletion: $error\n$stackTrace');
      if (mounted) {
        await _setAccountDeletionError(
          'Account deletion failed while '
          '${_accountDeletionStatus?.toLowerCase() ?? 'preparing'}: $error',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletingAccount = false;
          _accountDeletionStatus = null;
        });
      }
    }
  }

  Future<void> _setAccountDeletionError(String message) async {
    setState(() => _accountDeletionError = message);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Account deletion not completed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _accountDeletionAuthMessage(
    FirebaseAuthException error,
    bool usesGoogle,
  ) => switch (error.code) {
    'wrong-password' => 'That password is incorrect.',
    'user-mismatch' => 'Select the Google account linked to this account.',
    'invalid-credential' =>
      usesGoogle
          ? 'Google verification failed. Select the Google account linked to '
                'this VertivEra account and try again.'
          : 'That password is incorrect.',
    'requires-recent-login' =>
      'Please sign in again, then retry account deletion.',
    _ =>
      'Could not verify your account: ${error.message ?? 'please try again.'}',
  };

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: _authStateChanges,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Text('Could not check account status: ${snapshot.error}'),
          ),
        );
      }
      return _buildSettings(context, snapshot.data);
    },
  );

  Widget _buildSettings(BuildContext context, User? user) {
    if (user?.uid != _notificationUserId) {
      _notificationUserId = user?.uid;
      if (user == null) {
        notif = false;
        binAlert = false;
        _notificationSettingsLoading = false;
      } else {
        _notificationSettingsLoading = true;
        unawaited(_loadNotificationSettings(user.uid));
      }
    }
    final displayName =
        user?.displayName ?? user?.email?.split('@').first ?? 'User';
    if (user?.uid != _co2SavingsUserId) {
      _co2SavingsUserId = user?.uid;
      _co2SavingsStream = user == null
          ? null
          : _co2SavingsService.watchTotalKg(user.uid);
    }
    if (user != null && _loadedProfileUserId != user.uid) {
      _loadProfileImage(user.uid);
    }
    final profileImageUrl = user?.uid == _loadedProfileUserId
        ? _profileImageUrl
        : null;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                'Settings',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            child: profileImageUrl != null
                                ? ClipOval(
                                    child: Image.network(
                                      profileImageUrl,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const Icon(Icons.person, size: 32),
                                    ),
                                  )
                                : const Icon(Icons.person, size: 32),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  user?.email ?? '',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit account',
                            onPressed: user == null
                                ? null
                                : () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const AccountSettingsPage(),
                                      ),
                                    );
                                    await _loadProfileImage(user.uid);
                                  },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          StreamBuilder<double>(
                            stream: _co2SavingsStream,
                            builder: (context, snapshot) {
                              if (user == null) {
                                return const _Stat('—', 'CO₂ saved');
                              }
                              if (snapshot.hasError) {
                                return Tooltip(
                                  message:
                                      'Could not load CO₂ total: '
                                      '${snapshot.error}',
                                  child: const _Stat(
                                    'Unavailable',
                                    'CO₂ saved',
                                  ),
                                );
                              }
                              final totalKg = snapshot.data;
                              return _Stat(
                                totalKg == null
                                    ? 'Loading…'
                                    : '${totalKg.toStringAsFixed(1)} kg',
                                'CO₂ saved',
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _head('Preferences'),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Push notifications'),
              value: notif,
              subtitle: const Text('Allow alerts from VertivEra.'),
              onChanged:
                  user == null ||
                      _notificationSettingsLoading ||
                      _savingNotificationSettings
                  ? null
                  : _setPushNotifications,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.delete_outline),
              title: const Text('Nearby bin full alerts'),
              value: binAlert,
              subtitle: const Text(
                'Uses background location to check whether your closest bin is full.',
              ),
              onChanged:
                  user == null ||
                      !notif ||
                      _notificationSettingsLoading ||
                      _savingNotificationSettings
                  ? null
                  : _setBinAlerts,
            ),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeMode,
              builder: (_, m, _) => SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark mode'),
                value: m == ThemeMode.dark,
                onChanged: (v) =>
                    themeMode.value = v ? ThemeMode.dark : ThemeMode.light,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              trailing: Text(lang, style: const TextStyle(color: Colors.grey)),
              onTap: () => showModalBottomSheet(
                context: context,
                builder: (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: supportedAppLocales
                      .map(
                        (locale) => ListTile(
                          title: Text(languageName(locale)),
                          trailing: locale == appLocale.value
                              ? const Icon(Icons.check, color: kGreen)
                              : null,
                          onTap: () async {
                            await _selectLanguage(locale);
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            _head('Account'),
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: const Text('Saved addresses'),
              trailing: const Icon(Icons.chevron_right),
              onTap: user == null
                  ? null
                  : () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => SavedAddressesPage(userId: user.uid),
                      ),
                    ),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Payment methods'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const PaymentMethodsPage(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.card_giftcard),
              title: const Text('Rewards & vouchers'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => RewardsVouchersPage(
                    co2SavingsStream: user == null
                        ? null
                        : _co2SavingsService.watchTotalKg(user.uid),
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Pickup history'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const PickupHistoryPage(),
                ),
              ),
            ),
            _head('Support'),
            _nav(Icons.help_outline, 'Help centre'),
            _nav(Icons.privacy_tip_outlined, 'Privacy & terms'),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About VertivEra  ·  v1.0.0'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const AboutVertivEraPage(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (user != null)
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Log out',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Log out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _signOut();
                        },
                        child: const Text('Log out'),
                      ),
                    ],
                  ),
                ),
              ),
            if (user != null)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  'Delete account',
                  style: TextStyle(color: Colors.red),
                ),
                subtitle: const Text(
                  'Permanently remove your account and data',
                ),
                trailing: _deletingAccount
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                enabled: !_deletingAccount,
                onTap: _deletingAccount
                    ? null
                    : () => _confirmDeleteAccount(user),
              ),
            if (_deletingAccount && _accountDeletionStatus != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _accountDeletionStatus!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (_accountDeletionError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _accountDeletionError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _loadNotificationSettings(String userId) async {
    try {
      var settings = await _binNotificationService.loadSettings(userId);
      var startupWarning = settings.warning;
      if (!settings.hasSavedSettings) {
        startupWarning = await _binNotificationService.requestAtStartupIfNeeded(
          userId,
        );
        if (startupWarning == null) {
          settings = const BinNotificationSettings(
            pushEnabled: true,
            binAlertsEnabled: true,
            hasSavedSettings: true,
          );
        }
      }
      if (!mounted || _notificationUserId != userId) return;
      setState(() {
        notif = settings.pushEnabled;
        binAlert = settings.binAlertsEnabled;
        _notificationSettingsLoading = false;
      });
      if (startupWarning != null) snack(context, startupWarning);
    } on Exception catch (error) {
      debugPrint('Unable to load bin notification settings: $error');
      if (!mounted || _notificationUserId != userId) return;
      setState(() => _notificationSettingsLoading = false);
      snack(context, 'Could not load notification settings.');
    }
  }

  Future<void> _setPushNotifications(bool enabled) async {
    final userId = _notificationUserId;
    if (userId == null) return;
    final previousPush = notif;
    final previousAlerts = binAlert;
    setState(() {
      _savingNotificationSettings = true;
      notif = enabled;
      if (!enabled) binAlert = false;
    });
    try {
      await _binNotificationService.updateSettings(
        userId,
        pushEnabled: enabled,
        binAlertsEnabled: enabled && previousAlerts,
      );
    } on Exception catch (error) {
      debugPrint('Unable to update push notification settings: $error');
      if (mounted) {
        setState(() {
          notif = previousPush;
          binAlert = previousAlerts;
        });
        snack(context, _notificationErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _savingNotificationSettings = false);
    }
  }

  Future<void> _setBinAlerts(bool enabled) async {
    final userId = _notificationUserId;
    if (userId == null) return;
    final previous = binAlert;
    setState(() {
      _savingNotificationSettings = true;
      binAlert = enabled;
    });
    try {
      await _binNotificationService.updateSettings(
        userId,
        pushEnabled: notif,
        binAlertsEnabled: enabled,
      );
    } on Exception catch (error) {
      debugPrint('Unable to update nearby bin alert settings: $error');
      if (mounted) {
        setState(() => binAlert = previous);
        snack(context, _notificationErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _savingNotificationSettings = false);
    }
  }

  String _notificationErrorMessage(Object error) {
    if (error is BinNotificationPermissionException) return error.message;
    return 'Could not update notification settings: $error';
  }

  Future<void> _loadProfileImage(String userId) async {
    _loadedProfileUserId = userId;
    try {
      final url = await _profileImageService.loadUrl(userId);
      if (mounted && _loadedProfileUserId == userId) {
        setState(() => _profileImageUrl = url);
      }
    } on Exception catch (error) {
      debugPrint('Unable to load profile picture in Settings: $error');
      if (mounted && _loadedProfileUserId == userId) {
        snack(context, 'Could not load your saved profile picture.');
      }
    }
  }

  Widget _head(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
    child: Text(
      t.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.grey,
      ),
    ),
  );

  Widget _nav(IconData i, String t) => ListTile(
    leading: Icon(i),
    title: Text(t),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => snack(context, t),
  );
}

class _Stat extends StatelessWidget {
  final String v, l;
  const _Stat(this.v, this.l);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        v,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: kGreen,
        ),
      ),
      Text(l, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    ],
  );
}
