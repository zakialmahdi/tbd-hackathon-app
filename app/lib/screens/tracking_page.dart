import 'package:flutter/material.dart';

import '../app_config.dart';
import '../shared_widgets.dart';
import 'map_painter.dart';

class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});
  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController ctl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  )..forward();
  static const route = [
    Offset(0.15, 0.75),
    Offset(0.40, 0.75),
    Offset(0.40, 0.45),
    Offset(0.70, 0.45),
  ];
  static const stages = [
    'Finding driver',
    'Driver on the way',
    'Driver arrived',
    'Loading items',
    'Completed',
  ];

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  int _stage(double t) => t < .1
      ? 0
      : t < .7
      ? 1
      : t < .8
      ? 2
      : t < 1
      ? 3
      : 4;

  Offset _truck(double t) {
    final p = ((t - .1) / .6).clamp(0.0, 1.0);
    var lens = <double>[];
    double total = 0;
    for (var i = 0; i < route.length - 1; i++) {
      final l = (route[i + 1] - route[i]).distance;
      lens.add(l);
      total += l;
    }
    var d = p * total;
    for (var i = 0; i < lens.length; i++) {
      if (d <= lens[i]) {
        return Offset.lerp(
          route[i],
          route[i + 1],
          lens[i] == 0 ? 0 : d / lens[i],
        )!;
      }
      d -= lens[i];
    }
    return route.last;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: AnimatedBuilder(
        animation: ctl,
        builder: (_, __) {
          final t = ctl.value;
          final st = _stage(t);
          final eta = ((1 - (t / .7).clamp(0, 1)) * 12).ceil();
          return Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (_, c) {
                    final truck = _truck(t);
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: MapPainter(dark: dark, route: route),
                          ),
                        ),
                        Positioned(
                          left: route.last.dx * c.maxWidth - 20,
                          top: route.last.dy * c.maxHeight - 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                        if (st >= 1 && st < 3)
                          Positioned(
                            left: truck.dx * c.maxWidth - 20,
                            top: truck.dy * c.maxHeight - 20,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: kGreen,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    blurRadius: 6,
                                    color: Colors.black26,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.local_shipping,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: const [
                      BoxShadow(blurRadius: 16, color: Colors.black26),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                stages[st],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (st == 1)
                              Text(
                                '$eta min',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: kGreen,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: st == 0 ? null : (st + 1) / stages.length,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        const SizedBox(height: 14),
                        if (st >= 1) ...[
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 26,
                                child: Icon(Icons.person, size: 28),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ahmad Zulkifli',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '★ 4.9 · Lorry 10ft · BQK 2381',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton.filledTonal(
                                onPressed: () =>
                                    snack(context, 'Calling driver…'),
                                icon: const Icon(Icons.call),
                              ),
                              IconButton.filledTonal(
                                onPressed: () => snack(context, 'Chat opened'),
                                icon: const Icon(Icons.chat_bubble_outline),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                        ],
                        Row(
                          children: const [
                            Icon(Icons.inventory_2_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Sofa, Mattress · RM 80 · TNG eWallet'),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (st == 4)
                          FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Rate driver'),
                          )
                        else
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              foregroundColor: Colors.red,
                            ),
                            onPressed: st >= 2
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    snack(context, 'Request cancelled');
                                  },
                            child: const Text('Cancel request'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
