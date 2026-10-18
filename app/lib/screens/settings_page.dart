import 'package:flutter/material.dart';

import '../app_config.dart';
import '../shared_widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notif = true, binAlert = true;
  String lang = 'English';

  @override
  Widget build(BuildContext context) => Scaffold(
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
                        const CircleAvatar(
                          radius: 30,
                          child: Icon(Icons.person, size: 32),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Aiman Hakim',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'aiman@email.com',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const [
                        _Stat('1,240', 'Eco points'),
                        _Stat('38 kg', 'CO₂ saved'),
                        _Stat('Lv. 4', 'Eco Hero'),
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
            builder: (_, m, __) => SwitchListTile(
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
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log out', style: TextStyle(color: Colors.red)),
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
                    onPressed: () => Navigator.pop(context),
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
