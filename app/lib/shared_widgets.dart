import 'package:flutter/material.dart';

import 'app_config.dart';
import 'models.dart';

Widget sectionTitle(String t, {Widget? trailing}) => Padding(
  padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
  child: Row(
    children: [
      Expanded(
        child: Text(
          t,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      if (trailing != null) trailing,
    ],
  ),
);

void snack(BuildContext c, String m) => ScaffoldMessenger.of(c)
  ..hideCurrentSnackBar()
  ..showSnackBar(
    SnackBar(content: Text(m), behavior: SnackBarBehavior.floating),
  );

Widget reportTile(ReportItem r) {
  final col = switch (r.status) {
    'Resolved' => kGreen,
    'In progress' => Colors.orange,
    'Rejected' => Colors.red,
    _ => Colors.blue,
  };
  return ListTile(
    leading: CircleAvatar(
      backgroundColor: col.withOpacity(.15),
      child: Icon(r.icon, color: col),
    ),
    title: Text(r.title),
    subtitle: Text('${r.location} · ${r.date}'),
    trailing: Text(
      r.status,
      style: TextStyle(color: col, fontWeight: FontWeight.w700, fontSize: 12),
    ),
  );
}
