import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/announcement.dart';
import '../models/store.dart';

final announcementServiceProvider = Provider<AnnouncementService>((ref) {
  return AnnouncementService();
});

/// Pure mock announcement service — in-memory data persists until refresh
class AnnouncementService {
  Future<List<Announcement>> getAnnouncements({int? page, int? perPage}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List<Announcement>.from(mockAnnouncements);
  }

  Future<Announcement> getAnnouncement(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return mockAnnouncements.firstWhere((a) => a.id == id);
  }
}

// ─── Prototype Data ────────────────────────────────────────

final mockAnnouncements = <Announcement>[
  Announcement(
    id: 'ann-001',
    store: const Store(id: 'store-001', name: 'Cafe Bloom'),
    title: 'New Spring Menu Launch',
    content: 'We are launching a new spring menu next Monday. Please review the new items and preparation guides attached in the staff portal. Training sessions will be held this Friday at 2 PM.\n\nNew items include:\n- Lavender Oat Latte\n- Cherry Blossom Matcha\n- Strawberry Basil Lemonade\n\nPlease familiarize yourself with the preparation steps before the training.',
    createdByName: 'Manager Kim',
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
  ),
  Announcement(
    id: 'ann-002',
    title: 'Updated Break Policy',
    content: 'Starting next week, all staff are required to log their break times in the app. Please make sure to clock in and out for each break. This helps us ensure compliance with labor regulations and fair scheduling.',
    createdByName: 'HR Team',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  Announcement(
    id: 'ann-003',
    store: const Store(id: 'store-002', name: 'Bistro Garden'),
    title: 'Weekend Shift Bonus',
    content: 'Staff working weekend shifts this month will receive a 15% bonus. Sign up for available slots through the schedule page. First come, first served!',
    createdByName: 'Manager Park',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
  Announcement(
    id: 'ann-004',
    title: 'System Maintenance Notice',
    content: 'The TaskManager app will undergo scheduled maintenance on Sunday from 2 AM to 5 AM. During this time, you will not be able to access the app. Please plan accordingly and complete any pending checklist items before the maintenance window.',
    createdByName: 'IT Team',
    createdAt: DateTime.now().subtract(const Duration(days: 4)),
  ),
  Announcement(
    id: 'ann-005',
    store: const Store(id: 'store-003', name: 'Seoul Station Bakery'),
    title: 'Health Inspection Preparation',
    content: 'We have a scheduled health inspection next Wednesday. Please ensure all areas are clean and organized. Pay special attention to:\n\n1. Food storage temperatures\n2. Expiry date labels\n3. Hand sanitizer stations\n4. Floor cleanliness\n\nManager Lee will do a pre-inspection walkthrough on Tuesday.',
    createdByName: 'Manager Lee',
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
  ),
];
