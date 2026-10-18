import 'package:flutter/material.dart';

import '../models.dart';
import '../shared_widgets.dart';

class MyReportsPage extends StatelessWidget {
  const MyReportsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My reports')),
    body: ListView(children: myReports.map(reportTile).toList()),
  );
}
