import 'package:flutter/material.dart';

import '../app_config.dart';
import 'tracking_page.dart';

class BulkyRequestPage extends StatefulWidget {
  const BulkyRequestPage({super.key});
  @override
  State<BulkyRequestPage> createState() => _BulkyRequestPageState();
}

class _BulkyRequestPageState extends State<BulkyRequestPage> {
  static const types = <String, IconData>{
    'Sofa': Icons.weekend,
    'Mattress': Icons.bed,
    'Fridge': Icons.kitchen,
    'Wardrobe': Icons.door_sliding,
    'Electronics': Icons.tv,
    'Garden waste': Icons.grass,
  };
  static const vehicles = [
    ['Van', 'Up to 3 items', 45],
    ['Lorry 10ft', 'Up to 6 items', 80],
    ['Lorry 14ft', 'Up to 12 items', 120],
  ];
  final selected = <String>{'Sofa'};
  int vehicle = 0;
  bool now = true;
  bool helper = false;

  @override
  Widget build(BuildContext context) {
    final price = (vehicles[vehicle][2] as int) + (helper ? 20 : 0);
    return Scaffold(
      appBar: AppBar(title: const Text('Bulky waste pickup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'What do you need removed?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: types.entries
                .map(
                  (e) => FilterChip(
                    avatar: Icon(e.value, size: 18),
                    label: Text(e.key),
                    selected: selected.contains(e.key),
                    onSelected: (v) => setState(
                      () => v ? selected.add(e.key) : selected.remove(e.key),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          const Text(
            'Choose a vehicle',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < vehicles.length; i++)
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: vehicle == i ? kGreen : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ListTile(
                onTap: () => setState(() => vehicle = i),
                leading: const Icon(Icons.local_shipping, size: 32),
                title: Text(vehicles[i][0] as String),
                subtitle: Text(vehicles[i][1] as String),
                trailing: Text(
                  'RM ${vehicles[i][2]}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Add loading helper'),
            subtitle: const Text('+ RM 20'),
            value: helper,
            onChanged: (v) => setState(() => helper = v),
          ),
          const Divider(),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.trip_origin, color: kGreen),
            title: Text('Pickup address'),
            subtitle: Text('No. 12, Jalan Reko, 43000 Kajang'),
            trailing: Icon(Icons.chevron_right),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Now'),
                icon: Icon(Icons.bolt),
              ),
              ButtonSegment(
                value: false,
                label: Text('Schedule'),
                icon: Icon(Icons.calendar_today),
              ),
            ],
            selected: {now},
            onSelectionChanged: (s) => setState(() => now = s.first),
          ),
          if (!now)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: const Text('Tomorrow, 10:00 AM'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          const SizedBox(height: 8),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Note to driver (optional)',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 12),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.account_balance_wallet_outlined),
            title: Text('Payment'),
            subtitle: Text('Touch \'n Go eWallet'),
            trailing: Icon(Icons.chevron_right),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estimated fare',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    'RM $price',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TrackingPage(),
                          ),
                        ),
                  child: const Text('Request truck'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
