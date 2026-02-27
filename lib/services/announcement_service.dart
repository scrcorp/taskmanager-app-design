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

  Future<NoticeComment> addComment(String announcementId, String text) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final comment = NoticeComment(
      id: 'nc-${DateTime.now().millisecondsSinceEpoch}',
      userId: 'user-current',
      userName: 'Me',
      text: text,
      createdAt: DateTime.now(),
    );
    final idx = mockAnnouncements.indexWhere((a) => a.id == announcementId);
    if (idx != -1) {
      final ann = mockAnnouncements[idx];
      mockAnnouncements[idx] = ann.copyWith(
        comments: [...ann.comments, comment],
      );
    }
    return comment;
  }

  Future<Announcement> toggleAcknowledge(String announcementId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final idx = mockAnnouncements.indexWhere((a) => a.id == announcementId);
    if (idx == -1) throw Exception('Announcement not found');

    final ann = mockAnnouncements[idx];
    if (ann.isAcknowledged) {
      // Remove acknowledgment
      final updated = ann.copyWith(
        acknowledgments: ann.acknowledgments
            .where((a) => a.userId != 'user-current')
            .toList(),
        isAcknowledged: false,
      );
      mockAnnouncements[idx] = updated;
      return updated;
    } else {
      // Add acknowledgment
      final ack = NoticeAcknowledgment(
        userId: 'user-current',
        userName: 'Me',
        acknowledgedAt: DateTime.now(),
      );
      final updated = ann.copyWith(
        acknowledgments: [...ann.acknowledgments, ack],
        isAcknowledged: true,
      );
      mockAnnouncements[idx] = updated;
      return updated;
    }
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
    acknowledgments: [
      NoticeAcknowledgment(
        userId: 'user-002',
        userName: 'Staff Park',
        acknowledgedAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      NoticeAcknowledgment(
        userId: 'user-003',
        userName: 'Staff Lee',
        acknowledgedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ],
    comments: [
      NoticeComment(
        id: 'nc-001',
        userId: 'user-002',
        userName: 'Staff Park',
        text: 'Can we get the recipe guides before Friday?',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        likes: 2,
      ),
      NoticeComment(
        id: 'nc-002',
        userId: 'user-003',
        userName: 'Staff Lee',
        text: 'What time does the training start on Friday?',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        likes: 1,
      ),
    ],
  ),
  Announcement(
    id: 'ann-002',
    title: 'Updated Break Policy',
    content: 'Starting next week, all staff are required to log their break times in the app. Please make sure to clock in and out for each break. This helps us ensure compliance with labor regulations and fair scheduling.',
    createdByName: 'HR Team',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    isAcknowledged: true,
    acknowledgments: [
      NoticeAcknowledgment(
        userId: 'user-current',
        userName: 'Me',
        acknowledgedAt: DateTime.now().subtract(const Duration(hours: 20)),
      ),
      NoticeAcknowledgment(
        userId: 'user-002',
        userName: 'Staff Park',
        acknowledgedAt: DateTime.now().subtract(const Duration(hours: 18)),
      ),
      NoticeAcknowledgment(
        userId: 'user-004',
        userName: 'Staff Choi',
        acknowledgedAt: DateTime.now().subtract(const Duration(hours: 16)),
      ),
    ],
    comments: [
      NoticeComment(
        id: 'nc-003',
        userId: 'user-004',
        userName: 'Staff Choi',
        text: 'Does this apply to short 5-minute breaks too?',
        createdAt: DateTime.now().subtract(const Duration(hours: 18)),
        likes: 3,
      ),
    ],
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
