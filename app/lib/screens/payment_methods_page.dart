import 'package:flutter/material.dart';

import '../app_config.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  bool _cashOnPickupAdded = false;

  Future<void> _showAddPaymentMethod() async {
    final method = await showModalBottomSheet<_PaymentMethod>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add a payment method',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you would like to pay for future services.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.credit_card_outlined),
                ),
                title: const Text('Credit or debit card'),
                subtitle: const Text('Secure card setup is coming soon'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, _PaymentMethod.card),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.payments_outlined),
                ),
                title: const Text('Cash on pickup'),
                subtitle: const Text('Pay in person when your pickup is done'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, _PaymentMethod.cash),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || method == null) return;
    switch (method) {
      case _PaymentMethod.card:
        _showCardPaymentsNotice();
      case _PaymentMethod.cash:
        if (_cashOnPickupAdded) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('Cash on pickup is already in your methods.'),
              ),
            );
          return;
        }
        setState(() => _cashOnPickupAdded = true);
    }
  }

  void _showCardPaymentsNotice() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_outline),
        title: const Text('Card payments are coming soon'),
        content: const Text(
          'Card payments are not set up yet. VertivEra does not collect or '
          'store card numbers. A secure payment provider will be connected '
          'before card entry is enabled.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeCashOnPickup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove payment method?'),
        content: const Text('Remove Cash on pickup from this page?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _cashOnPickupAdded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment methods')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kGreen.withValues(alpha: 0.09),
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
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: kGreen,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage payments',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Choose a convenient way to pay.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'YOUR METHODS',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (!_cashOnPickupAdded)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.credit_card_off_outlined,
                      size: 40,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No payment methods yet',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add a payment option to see it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.payments_outlined),
                ),
                title: const Text('Cash on pickup'),
                subtitle: const Text('Pay in person after pickup'),
                trailing: IconButton(
                  tooltip: 'Remove payment method',
                  onPressed: _removeCashOnPickup,
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _showAddPaymentMethod,
            icon: const Icon(Icons.add),
            label: const Text('Add payment method'),
          ),
          const SizedBox(height: 16),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Card payments are not available yet. Card details are not '
                  'collected or stored in this app.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _PaymentMethod { card, cash }
