import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models.dart';

class ReportPage extends StatefulWidget {
  final String initial;
  const ReportPage({super.key, this.initial = 'Blocked drain'});
  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  late String cat = widget.initial;
  bool anon = false;
  int photos = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lodge a report')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'What are you reporting?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: reportCats.entries
              .map(
                (e) => ChoiceChip(
                  avatar: Icon(e.value, size: 18),
                  label: Text(e.key),
                  selected: cat == e.key,
                  onSelected: (_) => setState(() => cat = e.key),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        const Text('Photos', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < photos; i++)
                Container(
                  width: 84,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.image, color: Colors.grey),
                ),
              if (photos < 4)
                InkWell(
                  onTap: () => setState(() => photos++),
                  child: Container(
                    width: 84,
                    decoration: BoxDecoration(
                      border: Border.all(color: kGreen),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_a_photo_outlined,
                      color: kGreen,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              Container(
                height: 110,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  color: const Color(0xFFEAF1E4),
                ),
                child: const Center(
                  child: Icon(Icons.location_on, color: Colors.red, size: 40),
                ),
              ),
              const ListTile(
                leading: Icon(Icons.my_location),
                title: Text('Jalan Reko, Kajang'),
                subtitle: Text('Detected from GPS'),
                trailing: Text(
                  'Change',
                  style: TextStyle(color: kGreen, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const TextField(
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Describe the problem',
            alignLabelWithHint: true,
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Submit anonymously'),
          value: anon,
          onChanged: (v) => setState(() => anon = v),
        ),
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          onPressed: () => _done(context),
          child: const Text('Submit report'),
        ),
      ],
    ),
  );

  void _done(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: kGreen, size: 56),
        title: const Text('Report submitted'),
        content: const Text(
          'Reference #VR-20481. The council will review it within 48 hours. You\'ll be notified of any update.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
