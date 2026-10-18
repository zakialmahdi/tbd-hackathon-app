import 'package:flutter/material.dart';

class Item {
  final String title, category, condition, seller, desc, distance;
  final double price;
  final IconData icon;
  final Color color;
  const Item(
    this.title,
    this.price,
    this.category,
    this.condition,
    this.seller,
    this.distance,
    this.desc,
    this.icon,
    this.color,
  );
}

const items = <Item>[
  Item(
    'Oak Study Chair',
    35,
    'Furniture',
    'Good',
    'Aisyah R.',
    '1.2 km',
    'Sturdy oak chair, minor scratches on legs. Perfect for a study corner.',
    Icons.chair_alt,
    Color(0xFFE8C9A0),
  ),
  Item(
    'City Bicycle 26"',
    120,
    'Sports',
    'Like new',
    'Daniel T.',
    '2.8 km',
    'Ridden less than 20 times. Includes basket and lock.',
    Icons.pedal_bike,
    Color(0xFFB7E0F2),
  ),
  Item(
    'MacBook Air 2017',
    850,
    'Electronics',
    'Fair',
    'Kevin L.',
    '4.1 km',
    '8GB RAM, 128GB SSD. Battery service recently done.',
    Icons.laptop_mac,
    Color(0xFFD5D5E8),
  ),
  Item(
    'Novel Bundle (12)',
    40,
    'Books',
    'Good',
    'Nurul H.',
    '0.8 km',
    'Mix of English & Malay novels. Sold as a bundle only.',
    Icons.menu_book,
    Color(0xFFF5D6D6),
  ),
  Item(
    'Blender 1.5L',
    25,
    'Home',
    'Good',
    'Mei Ling',
    '3.3 km',
    'Works perfectly, upgrading to a bigger model.',
    Icons.blender,
    Color(0xFFD6F0D0),
  ),
  Item(
    'Denim Jacket (M)',
    30,
    'Fashion',
    'Like new',
    'Farid A.',
    '1.9 km',
    'Worn twice. Classic fit, no stains.',
    Icons.checkroom,
    Color(0xFFC9D8F5),
  ),
  Item(
    'Kids Toy Set',
    18,
    'Kids',
    'Good',
    'Priya S.',
    '2.2 km',
    'Wooden blocks and cars, cleaned and sanitised.',
    Icons.toys,
    Color(0xFFFFE6A8),
  ),
  Item(
    'Potted Monstera',
    28,
    'Home',
    'New',
    'Hafiz M.',
    '5.0 km',
    'Healthy plant with pot. Propagated from my own garden.',
    Icons.yard,
    Color(0xFFBFE8C8),
  ),
];

enum BinStatus { empty, half, full, maintenance }

Color statusColor(BinStatus s) => switch (s) {
  BinStatus.empty => const Color(0xFF2E9E5B),
  BinStatus.half => const Color(0xFFF2A900),
  BinStatus.full => const Color(0xFFE5393B),
  BinStatus.maintenance => Colors.grey,
};
String statusLabel(BinStatus s) => switch (s) {
  BinStatus.empty => 'Empty',
  BinStatus.half => 'Half full',
  BinStatus.full => 'Full',
  BinStatus.maintenance => 'Out of service',
};

class Bin {
  final String id, name, type, emptied;
  final BinStatus status;
  final int fill;
  final double x, y; // fractions of map
  const Bin(
    this.id,
    this.name,
    this.type,
    this.status,
    this.fill,
    this.emptied,
    this.x,
    this.y,
  );
}

const bins = <Bin>[
  Bin(
    'D-014',
    'Jalan Reko Bin',
    'Domestic',
    BinStatus.full,
    96,
    'Yesterday 6:10 PM',
    0.15,
    0.20,
  ),
  Bin(
    'R-007',
    'Kajang Sentral Recycle Point',
    'Recycle',
    BinStatus.half,
    55,
    'Today 7:30 AM',
    0.40,
    0.20,
  ),
  Bin(
    'D-022',
    'Taman Sri Kajang Bin',
    'Domestic',
    BinStatus.empty,
    8,
    'Today 8:00 AM',
    0.70,
    0.20,
  ),
  Bin(
    'R-011',
    'Stadium Kajang Recycle Hub',
    'Recycle',
    BinStatus.empty,
    15,
    'Today 6:45 AM',
    0.40,
    0.45,
  ),
  Bin(
    'D-031',
    'Wet Market Bin',
    'Domestic',
    BinStatus.half,
    62,
    'Today 5:50 AM',
    0.70,
    0.45,
  ),
  Bin(
    'R-019',
    'Library Recycle Bin',
    'Recycle',
    BinStatus.full,
    91,
    '2 days ago',
    0.15,
    0.75,
  ),
  Bin(
    'D-040',
    'Bus Stop Bin A3',
    'Domestic',
    BinStatus.maintenance,
    0,
    'Under repair',
    0.40,
    0.75,
  ),
  Bin(
    'D-043',
    'Food Court Bin',
    'Domestic',
    BinStatus.half,
    48,
    'Today 9:15 AM',
    0.70,
    0.75,
  ),
  Bin(
    'R-024',
    'Mosque Recycle Point',
    'Recycle',
    BinStatus.empty,
    5,
    'Today 7:00 AM',
    0.90,
    0.60,
  ),
];

const reportCats = <String, IconData>{
  'Blocked drain': Icons.water_damage,
  'Bin full': Icons.delete_sweep,
  'Illegal dumping': Icons.report_problem,
  'Other': Icons.more_horiz,
};

class ReportItem {
  final String title, location, date, status;
  final IconData icon;
  const ReportItem(
    this.title,
    this.location,
    this.date,
    this.status,
    this.icon,
  );
}

const myReports = <ReportItem>[
  ReportItem(
    'Blocked drain',
    'Jalan Cheras Perdana',
    '16 Oct 2026',
    'In progress',
    Icons.water_damage,
  ),
  ReportItem(
    'Illegal dumping',
    'Behind Block C, Taman Sri',
    '10 Oct 2026',
    'Resolved',
    Icons.report_problem,
  ),
  ReportItem(
    'Bin full',
    'Jalan Reko',
    '2 Oct 2026',
    'Resolved',
    Icons.delete_sweep,
  ),
  ReportItem(
    'Blocked drain',
    'Lorong 5, Bandar Baru',
    '24 Sep 2026',
    'Rejected',
    Icons.water_damage,
  ),
];
