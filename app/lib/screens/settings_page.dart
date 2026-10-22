import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../services/auth_service.dart';
import '../services/co2_savings_service.dart';
import '../services/profile_image_service.dart';
import '../shared_widgets.dart';
import 'account_settings_page.dart';

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

  bool notif = true, binAlert = true;
  String lang = 'English';
  String? _profileImagePath;
  String? _loadedProfileUserId;
  String? _co2SavingsUserId;
  Stream<double>? _co2SavingsStream;

  Future<void> _signOut() async {
    try {
      await AuthService().signOut();
    } on Exception catch (error) {
      debugPrint('Unable to sign out: $error');
      if (mounted) snack(context, 'Could not sign out. Please try again.');
    }
  }

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
    final profileImagePath = user?.uid == _loadedProfileUserId
        ? _profileImagePath
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
                            child: profileImagePath != null
                                ? ClipOval(
                                    child: Image.file(
                                      File(profileImagePath),
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
              onChanged: (v) => setState(() => notif = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.delete_outline),
              title: const Text('Nearby bin full alerts'),
              value: binAlert,
              onChanged: (v) => setState(() => binAlert = v),
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
                  children: ['English', 'Bahasa Melayu', '中文', 'தமிழ்']
                      .map(
                        (l) => ListTile(
                          title: Text(l),
                          trailing: l == lang
                              ? const Icon(Icons.check, color: kGreen)
                              : null,
                          onTap: () {
                            setState(() => lang = l);
                            Navigator.pop(context);
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            _head('Account'),
            _nav(Icons.place_outlined, 'Saved addresses'),
            _nav(Icons.account_balance_wallet_outlined, 'Payment methods'),
            _nav(Icons.card_giftcard, 'Rewards & vouchers'),
            _nav(Icons.history, 'Pickup history'),
            _head('Support'),
            _nav(Icons.help_outline, 'Help centre'),
            _nav(Icons.privacy_tip_outlined, 'Privacy & terms'),
            _nav(Icons.info_outline, 'About VertivEra  ·  v1.0.0'),
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _loadProfileImage(String userId) async {
    _loadedProfileUserId = userId;
    try {
      final path = await _profileImageService.loadPath(userId);
      if (mounted && _loadedProfileUserId == userId) {
        setState(() => _profileImagePath = path);
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
