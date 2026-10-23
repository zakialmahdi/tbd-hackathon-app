import 'package:flutter/material.dart';

import '../app_config.dart';

class PickupHistoryPage extends StatefulWidget {
  const PickupHistoryPage({super.key});

  @override
  State<PickupHistoryPage> createState() => _PickupHistoryPageState();
}

class _PickupHistoryPageState extends State<PickupHistoryPage> {
  static const _filters = ['All', 'Completed', 'Cancelled'];
  static final _pickups = <_Pickup>[
    _Pickup(
      id: 'VE-240819',
      items: const ['Sofa', 'Mattress'],
      date: DateTime(2026, 10, 18, 10, 30),
      address: 'No. 12, Jalan Reko, Kajang',
      fare: 65,
      status: _PickupStatus.completed,
    ),
    _Pickup(
      id: 'VE-240702',
      items: const ['Fridge'],
      date: DateTime(2026, 10, 11, 14, 0),
      address: '18, Jalan Tasik Selatan, Kuala Lumpur',
      fare: 45,
      status: _PickupStatus.completed,
    ),
    _Pickup(
      id: 'VE-240511',
      items: const ['Wardrobe', 'Garden waste'],
      date: DateTime(2026, 10, 4, 9, 0),
      address: 'No. 12, Jalan Reko, Kajang',
      fare: 100,
      status: _PickupStatus.cancelled,
    ),
  ];

  String _selectedFilter = 'All';

  List<_Pickup> get _visiblePickups => _pickups.where((pickup) {
    return _selectedFilter == 'All' || pickup.status.label == _selectedFilter;
  }).toList();

  @override
  Widget build(BuildContext context) {
    final completedCount = _pickups
        .where((pickup) => pickup.status == _PickupStatus.completed)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Pickup history')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _summaryCard(completedCount),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your pickups',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${_visiblePickups.length} '
                '${_visiblePickups.length == 1 ? 'record' : 'records'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((filter) {
                final selected = filter == _selectedFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedFilter = filter),
                    selectedColor: kGreen.withValues(alpha: 0.15),
                    side: BorderSide(
                      color: selected ? kGreen : Colors.transparent,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          if (_visiblePickups.isEmpty)
            _emptyState()
          else
            ..._visiblePickups.map(
              (pickup) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PickupCard(
                  pickup: pickup,
                  onTap: () => _showDetails(pickup),
                ),
              ),
            ),
          const SizedBox(height: 4),
          _previewNotice(),
        ],
      ),
    );
  }

  Widget _summaryCard(int completedCount) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: kGreen.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: kGreen.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.local_shipping_outlined, color: kGreen),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$completedCount pickups completed',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Thanks for giving bulky items a better next step.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
    child: Column(
      children: [
        Icon(
          Icons.history,
          size: 52,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 12),
        Text(
          'No ${_selectedFilter.toLowerCase()} pickups',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Try another filter to see your pickup records.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  Widget _previewNotice() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Preview only: these sample pickup records are not saved to your account.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );

  void _showDetails(_Pickup pickup) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pickup details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    _StatusBadge(status: pickup.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Booking ${pickup.id}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: 28),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  title: 'Date and time',
                  detail: _formatDate(pickup.date),
                ),
                const SizedBox(height: 16),
                _DetailRow(
                  icon: Icons.delete_outline,
                  title: 'Items',
                  detail: pickup.items.join(', '),
                ),
                const SizedBox(height: 16),
                _DetailRow(
                  icon: Icons.place_outlined,
                  title: 'Pickup address',
                  detail: pickup.address,
                ),
                const SizedBox(height: 16),
                _DetailRow(
                  icon: Icons.receipt_long_outlined,
                  title: 'Fare',
                  detail: pickup.status == _PickupStatus.cancelled
                      ? 'No charge'
                      : 'RM ${pickup.fare.toStringAsFixed(2)}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickupCard extends StatelessWidget {
  final _Pickup pickup;
  final VoidCallback onTap;

  const _PickupCard({required this.pickup, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(pickup.date),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                _StatusBadge(status: pickup.status),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: kGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    color: kGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pickup.items.join(' + '),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pickup.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Text(
                  'Booking ${pickup.id}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  pickup.status == _PickupStatus.cancelled
                      ? 'No charge'
                      : 'RM ${pickup.fare.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: kGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final _PickupStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == _PickupStatus.completed
        ? kGreen
        : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _DetailRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: kGreen),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            Text(detail, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ],
  );
}

String _formatDate(DateTime date) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final weekday = weekdays[date.weekday - 1];
  final month = months[date.month - 1];
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour < 12 ? 'AM' : 'PM';
  return '$weekday, $month ${date.day}, ${date.year} · $hour:$minute $period';
}

enum _PickupStatus {
  completed('Completed'),
  cancelled('Cancelled');

  final String label;

  const _PickupStatus(this.label);
}

class _Pickup {
  final String id;
  final List<String> items;
  final DateTime date;
  final String address;
  final double fare;
  final _PickupStatus status;

  const _Pickup({
    required this.id,
    required this.items,
    required this.date,
    required this.address,
    required this.fare,
    required this.status,
  });
}
