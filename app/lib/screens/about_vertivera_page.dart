import 'package:flutter/material.dart';

import '../app_config.dart';

class AboutVertivEraPage extends StatelessWidget {
  const AboutVertivEraPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About VertivEra')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF168B50), Color(0xFF32B56C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Container(
                  key: const ValueKey('vertivera-app-icon'),
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.recycling, color: kGreen, size: 48),
                ),
                SizedBox(height: 16),
                Text(
                  'VertivEra',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Waste less. Circle more.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'A cleaner future, together',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'VertivEra helps make sustainable choices easier in everyday life. '
            'Find ways to reuse, care for your neighbourhood, and make more '
            'responsible use of resources.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 24),
          Text(
            'WHAT YOU CAN DO',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const _AboutFeature(
            icon: Icons.storefront_outlined,
            title: 'Give items another life',
            description:
                'Discover pre-loved items and share what you no longer need.',
          ),
          const _AboutFeature(
            icon: Icons.map_outlined,
            title: 'Find nearby recycling bins',
            description:
                'Check bin locations and help keep recycling accessible.',
          ),
          const _AboutFeature(
            icon: Icons.volunteer_activism_outlined,
            title: 'Get help with bulky items',
            description:
                'Explore pickup services for items that are hard to move.',
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Text(
                  'VertivEra',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _AboutFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: kGreen.withValues(alpha: 0.1),
      child: Icon(icon, color: kGreen),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(description),
  );
}
