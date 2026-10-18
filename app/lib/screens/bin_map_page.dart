import 'package:flutter/material.dart';

import '../models.dart';
import '../shared_widgets.dart';
import 'map_painter.dart';
import 'report_page.dart';

class BinMapPage extends StatefulWidget {
  const BinMapPage({super.key});
  @override
  State<BinMapPage> createState() => _BinMapPageState();
}

class _BinMapPageState extends State<BinMapPage> {
  String filter = 'All';
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const size = 900.0;
    final shown = bins
        .where((b) => filter == 'All' || b.type == filter)
        .toList();
    return Scaffold(
      body: Stack(
        children: [
          InteractiveViewer(
            constrained: false,
            minScale: 0.6,
            maxScale: 2.5,
            boundaryMargin: const EdgeInsets.all(200),
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: MapPainter(dark: dark)),
                  ),
                  ...shown.map(
                    (b) => Positioned(
                      left: b.x * size - 22,
                      top: b.y * size - 44,
                      child: GestureDetector(
                        onTap: () => _showBin(b),
                        child: _pin(b),
                      ),
                    ),
                  ),
                  Positioned(
                    left: .55 * size - 12,
                    top: .60 * size - 12,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: SearchBar(
                    hintText: 'Search bins or address',
                    leading: const Icon(Icons.search),
                    trailing: [
                      IconButton(
                        onPressed: () => _showList(shown),
                        icon: const Icon(Icons.view_list_outlined),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final f in ['All', 'Domestic', 'Recycle'])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f),
                            selected: filter == f,
                            onSelected: (_) => setState(() => filter = f),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in BinStatus.values)
                      Row(
                        children: [
                          Icon(Icons.circle, size: 12, color: statusColor(s)),
                          const SizedBox(width: 6),
                          Text(
                            statusLabel(s),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: 'bin-map-location-fab',
              onPressed: () => snack(context, 'Centered on your location'),
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pin(Bin b) => Column(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: statusColor(b.status),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
        ),
        child: Icon(
          b.type == 'Recycle' ? Icons.recycling : Icons.delete,
          color: Colors.white,
          size: 22,
        ),
      ),
      Icon(Icons.arrow_drop_down, color: statusColor(b.status), size: 0),
    ],
  );

  void _showBin(Bin b) => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  b.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Chip(
                label: Text(
                  statusLabel(b.status),
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: statusColor(b.status),
                side: BorderSide.none,
              ),
            ],
          ),
          Text(
            '${b.type} bin · ID ${b.id}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('Fill level'),
              const Spacer(),
              Text(
                '${b.fill}%',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: b.fill / 100,
              minHeight: 10,
              color: statusColor(b.status),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.history, size: 18),
              const SizedBox(width: 8),
              Text('Last emptied: ${b.emptied}'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: const [
              Icon(Icons.directions_walk, size: 18),
              SizedBox(width: 8),
              Text('350 m away · 5 min walk'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportPage(
                          initial: b.status == BinStatus.full
                              ? 'Bin full'
                              : 'Other',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Report issue'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  void _showList(List<Bin> l) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .6,
      builder: (_, sc) => ListView(
        controller: sc,
        children: l
            .map(
              (b) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor(b.status),
                  child: Icon(
                    b.type == 'Recycle' ? Icons.recycling : Icons.delete,
                    color: Colors.white,
                  ),
                ),
                title: Text(b.name),
                subtitle: Text('${statusLabel(b.status)} · ${b.fill}%'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  _showBin(b);
                },
              ),
            )
            .toList(),
      ),
    ),
  );
}
