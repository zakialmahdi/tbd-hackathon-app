import 'package:flutter/material.dart';

class AccountDeletionConfirmationDialog extends StatelessWidget {
  const AccountDeletionConfirmationDialog({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
    title: const Text('Delete your account?'),
    content: const Text(
      'This permanently deletes your account, saved addresses, notification '
      'data, CO₂ total, and profile picture. This cannot be undone.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Delete account'),
      ),
    ],
  );
}

class AccountDeletionPasswordPage extends StatefulWidget {
  const AccountDeletionPasswordPage({super.key});

  @override
  State<AccountDeletionPasswordPage> createState() =>
      _AccountDeletionPasswordPageState();
}

class _AccountDeletionPasswordPageState
    extends State<AccountDeletionPasswordPage> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Verify your account'),
      leading: IconButton(
        tooltip: 'Cancel',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.lock_outline, size: 48, color: Colors.red),
          const SizedBox(height: 20),
          Text(
            'Confirm it’s you',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your account password to permanently delete your account.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: TextFormField(
              key: const ValueKey('account-deletion-password'),
              controller: _passwordController,
              obscureText: true,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _continue(),
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) =>
                  (value ?? '').isEmpty ? 'Enter your password.' : null,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: _continue,
            child: const Text('Continue to delete account'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
}
