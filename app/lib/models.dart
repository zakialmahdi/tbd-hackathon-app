import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Item {
  final String title, category, condition, seller, desc, distance;
  final double price;
  final IconData icon;
  final Color color;
  final String id;
  final String? ownerId;
  final String status;
  final String pickupAddress;
  final List<String> imageUrls;
  const Item(
    this.title,
    this.price,
    this.category,
    this.condition,
    this.seller,
    this.distance,
    this.desc,
    this.icon,
    this.color, {
    this.id = '',
    this.ownerId,
    this.status = 'active',
    this.pickupAddress = 'Pickup nearby',
    this.imageUrls = const [],
  }
  );

  factory Item.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) => Item.fromSnapshot(document);

  factory Item.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      throw FormatException('Listing document ${document.id} is empty.');
    }
    return Item.fromData(id: document.id, data: data);
  }

  factory Item.fromData({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final title = data['title'];
    final category = data['category'];
    final condition = data['condition'];
    final seller = data['seller'];
    final description = data['description'];
    final price = data['price'];
    final ownerId = data['ownerId'];
    final status = data['status'];
    if (title is! String ||
        category is! String ||
        condition is! String ||
        seller is! String ||
        description is! String ||
        price is! num ||
        ownerId is! String ||
        status is! String) {
      throw FormatException(
        'Listing document $id has invalid fields.',
      );
    }

    return Item(
      title,
      price.toDouble(),
      category,
      condition,
      seller,
        data['pickupAddress'] as String? ??
          data['distance'] as String? ??
          'Pickup nearby',
      description,
      iconForCategory(category),
      colorForCategory(category),
      id: id,
      ownerId: ownerId,
      status: status,
        pickupAddress: data['pickupAddress'] as String? ?? 'Pickup nearby',
        imageUrls: (data['imageUrls'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

IconData iconForCategory(String category) => switch (category) {
  'Furniture' => Icons.chair_alt,
  'Electronics' => Icons.devices,
  'Fashion' => Icons.checkroom,
  'Books' => Icons.menu_book,
  'Home' => Icons.home_outlined,
  'Sports' => Icons.sports_basketball,
  'Kids' => Icons.toys,
  _ => Icons.recycling,
};

Color colorForCategory(String category) => switch (category) {
  'Furniture' => const Color(0xFFE8C9A0),
  'Electronics' => const Color(0xFFD5D5E8),
  'Fashion' => const Color(0xFFC9D8F5),
  'Books' => const Color(0xFFF5D6D6),
  'Home' => const Color(0xFFD6F0D0),
  'Sports' => const Color(0xFFB7E0F2),
  'Kids' => const Color(0xFFFFE6A8),
  _ => const Color(0xFFBFE8C8),
};

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
  final String id, name, type;
  final BinStatus status;
  final int fill;
  final double latitude, longitude;
  final DateTime? emptied;
  final String? maintenanceNote;

  const Bin({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.fill,
    required this.latitude,
    required this.longitude,
    this.emptied,
    this.maintenanceNote,
  });

  factory Bin.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final name = data['name'];
    final type = data['type'];
    final rawStatus = data['status'];
    final fill = data['fill'];
    final location = data['location'];
    final emptied = data['emptied'];
    final maintenanceNote = data['maintenanceNote'];

    if (name is! String ||
        type is! String ||
        rawStatus is! String ||
        fill is! int ||
        fill < 0 ||
        fill > 100 ||
        (type != 'Domestic' && type != 'Recycle') ||
        location is! GeoPoint ||
        (emptied != null && emptied is! Timestamp) ||
        (maintenanceNote != null && maintenanceNote is! String)) {
      throw FormatException('Bin document ${document.id} has invalid fields.');
    }

    final status = BinStatus.values.where((value) {
      return value.name == rawStatus;
    });
    if (status.isEmpty) {
      throw FormatException(
        'Bin document ${document.id} has unknown status "$rawStatus".',
      );
    }

    return Bin(
      id: document.id,
      name: name,
      type: type,
      status: status.first,
      fill: fill,
      latitude: location.latitude,
      longitude: location.longitude,
      emptied: (emptied as Timestamp?)?.toDate(),
      maintenanceNote: maintenanceNote as String?,
    );
  }

  String get emptiedLabel {
    final date = emptied?.toLocal();
    if (date == null) return maintenanceNote ?? 'Not recorded';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'AM' : 'PM';
    return '${date.day}/${date.month}/${date.year} $hour:$minute $period';
  }
}

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
