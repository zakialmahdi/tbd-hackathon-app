import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models.dart';
import '../shared_widgets.dart';
import 'bulky_request_page.dart';
import 'my_reports_page.dart';
import 'report_page.dart';
import 'tracking_page.dart';

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                'Services',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Keep your neighbourhood clean',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _bigCard(
                      context,
                      Icons.local_shipping,
                      'Bulky Waste\nPickup',
                      'Book a truck now',
                      const [Color(0xFF1B9C5A), Color(0xFF4CC38A)],
                      const BulkyRequestPage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _bigCard(
                      context,
                      Icons.campaign,
                      'Lodge\nReport',
                      'Report an issue',
                      const [Color(0xFFEE7B30), Color(0xFFF5A962)],
                      const ReportPage(),
                    ),
                  ),
                ],
              ),
            ),
            sectionTitle('Quick report'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: .85,
                children: reportCats.entries
                    .map(
                      (e) => InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReportPage(initial: e.key),
                          ),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: cs.secondaryContainer,
                              child: Icon(
                                e.value,
                                color: cs.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              e.key,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            sectionTitle('Active pickup'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: kGreen,
                    child: Icon(Icons.local_shipping, color: Colors.white),
                  ),
                  title: const Text('Sofa + Mattress'),
                  subtitle: const Text('Driver on the way · ETA 12 min'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TrackingPage()),
                  ),
                ),
              ),
            ),
            sectionTitle(
              'My reports',
              trailing: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyReportsPage()),
                ),
                child: const Text('See all'),
              ),
            ),
            ...myReports.take(2).map(reportTile),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

Widget _bigCard(
  BuildContext c,
  IconData i,
  String t,
  String s,
  List<Color> g,
  Widget page,
) => InkWell(
  borderRadius: BorderRadius.circular(20),
  onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => page)),
  child: Ink(
    height: 160,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: g,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(i, color: Colors.white, size: 34),
        const Spacer(),
        Text(
          t,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(s, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    ),
  ),
);
