import 'package:flutter/material.dart';

import '../app_config.dart';

class RewardsVouchersPage extends StatefulWidget {
  final Stream<double>? co2SavingsStream;

  const RewardsVouchersPage({super.key, this.co2SavingsStream});

  @override
  State<RewardsVouchersPage> createState() => _RewardsVouchersPageState();
}

class _RewardsVouchersPageState extends State<RewardsVouchersPage>
    with SingleTickerProviderStateMixin {
  static const _rewards = <_Reward>[
    _Reward(
      id: 'remarket',
      title: 'RM5 ReMarket voucher',
      description: 'Save on your next pre-loved find.',
      requiredKg: 5,
      icon: Icons.shopping_bag_outlined,
      color: Color(0xFF3977C3),
    ),
    _Reward(
      id: 'cup',
      title: 'Reusable cup',
      description: 'A little everyday swap for the planet.',
      requiredKg: 10,
      icon: Icons.local_cafe_outlined,
      color: Color(0xFFB77635),
    ),
    _Reward(
      id: 'service',
      title: '10% off a service',
      description: 'Use on your next VertivEra service booking.',
      requiredKg: 20,
      icon: Icons.handyman_outlined,
      color: Color(0xFF8B61B2),
    ),
  ];

  late final _tabController = TabController(length: 2, vsync: this);
  final List<_Voucher> _vouchers = [];
  final Set<String> _claimedRewardIds = {};

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _redeem(_Reward reward) async {
    if (_claimedRewardIds.contains(reward.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(reward.icon, color: reward.color),
        title: Text('Claim ${reward.title}?'),
        content: Text(
          'You qualify with ${reward.requiredKg.toStringAsFixed(0)} kg of '
          'CO₂ saved. Claiming a reward does not reduce your CO₂ saved total.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Claim reward'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final code = 'ECO${DateTime.now().millisecondsSinceEpoch % 1000000}'
        .padRight(9, '0');
    setState(() {
      _claimedRewardIds.add(reward.id);
      _vouchers.insert(
        0,
        _Voucher(
          title: reward.title,
          code: code,
          expiresAt: DateTime.now().add(const Duration(days: 30)),
        ),
      );
    });
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards & vouchers'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Rewards'),
            Tab(text: 'My vouchers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildRewardsTab(), _buildVouchers()],
      ),
    );
  }

  Widget _buildRewardsTab() {
    final stream = widget.co2SavingsStream;
    if (stream == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Sign in to see your CO₂ savings and claim rewards.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return StreamBuilder<double>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load your CO₂ savings: ${snapshot.error}'),
            ),
          );
        }
        final co2SavedKg = snapshot.data;
        if (co2SavedKg == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildRewards(co2SavedKg);
      },
    );
  }

  Widget _buildRewards(double co2SavedKg) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
    children: [
      _co2SavingsCard(co2SavedKg),
      const SizedBox(height: 24),
      Text(
        'Claim your rewards',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(
        'Your reuse impact unlocks rewards as your CO₂ savings grow.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 12),
      for (final reward in _rewards) ...[
        _RewardCard(
          reward: reward,
          canClaim:
              co2SavedKg >= reward.requiredKg &&
              !_claimedRewardIds.contains(reward.id),
          claimed: _claimedRewardIds.contains(reward.id),
          onClaim: () => _redeem(reward),
        ),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 10),
      _previewNotice(),
    ],
  );

  Widget _co2SavingsCard(double co2SavedKg) {
    final nextReward = _rewards
        .where((reward) => reward.requiredKg > co2SavedKg)
        .firstOrNull;
    final progress = nextReward == null
        ? 1.0
        : (co2SavedKg / nextReward.requiredKg).clamp(0.0, 1.0);
    final remainingKg = nextReward == null
        ? 0.0
        : nextReward.requiredKg - co2SavedKg;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF168B50), Color(0xFF32B56C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco_outlined, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'YOUR CO₂ SAVED',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${co2SavedKg.toStringAsFixed(1)} kg',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Earned through your reuse activities.',
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            nextReward == null
                ? 'All listed rewards unlocked'
                : '${remainingKg.toStringAsFixed(1)} kg CO₂ to '
                      '${nextReward.title}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVouchers() => _vouchers.isEmpty
      ? ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 72),
            Icon(
              Icons.confirmation_number_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No vouchers yet',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Claim a reward with your CO₂ savings and your vouchers will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.card_giftcard_outlined),
                label: const Text('Explore rewards'),
              ),
            ),
            const SizedBox(height: 24),
            _previewNotice(),
          ],
        )
      : ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Text(
              'Ready to use',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final voucher in _vouchers) ...[
              _VoucherCard(voucher: voucher),
              const SizedBox(height: 12),
            ],
            _previewNotice(),
          ],
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
            'CO₂ savings come from your account. Claimed vouchers are temporary '
            'and will reset when you leave this page.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RewardCard extends StatelessWidget {
  final _Reward reward;
  final bool canClaim;
  final bool claimed;
  final VoidCallback onClaim;

  const _RewardCard({
    required this.reward,
    required this.canClaim,
    required this.claimed,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: reward.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(reward.icon, color: reward.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  reward.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.eco_outlined, size: 15, color: kGreen),
                    const SizedBox(width: 4),
                    Text(
                      '${reward.requiredKg.toStringAsFixed(0)} kg CO₂ saved',
                      style: const TextStyle(
                        color: kGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: canClaim ? onClaim : null,
            child: Text(claimed ? 'Claimed' : 'Claim'),
          ),
        ],
      ),
    ),
  );
}

class _VoucherCard extends StatelessWidget {
  final _Voucher voucher;

  const _VoucherCard({required this.voucher});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: kGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.card_giftcard_outlined, color: kGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  voucher.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text('Code: ${voucher.code}'),
                const SizedBox(height: 3),
                Text(
                  'Expires ${voucher.expiresAt.day}/${voucher.expiresAt.month}/${voucher.expiresAt.year}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Reward {
  final String id;
  final String title;
  final String description;
  final double requiredKg;
  final IconData icon;
  final Color color;

  const _Reward({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredKg,
    required this.icon,
    required this.color,
  });
}

class _Voucher {
  final String title;
  final String code;
  final DateTime expiresAt;

  const _Voucher({
    required this.title,
    required this.code,
    required this.expiresAt,
  });
}
