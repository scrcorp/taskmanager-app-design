# home-screen-redesign Design Document

> **Summary**: Complete technical design for replacing the Home screen with a personalized dashboard featuring time-based greeting, hashtag chips, quick-shortcut grid, and speech-bubble announcement banner.
>
> **Project**: Employee Management Service (Flutter Web)
> **Version**: 1.0.0
> **Author**: CTO Lead
> **Date**: 2026-02-20
> **Status**: Draft
> **Planning Doc**: [home-screen-redesign.plan.md](../01-plan/features/home-screen-redesign.plan.md)

---

## 1. Overview

### 1.1 Design Goals

- Replace the three-section data-listing home screen with a compact, personalized dashboard
- Reuse all existing Riverpod providers without new API endpoints
- Keep the file under 400 lines by extracting clear private widgets
- Maintain pull-to-refresh and the existing AppShell (header + bottom nav) contract

### 1.2 Design Principles

- **Data Reuse**: All displayed data comes from existing providers (auth, assignment, task)
- **Single Responsibility**: Each visual section is its own private widget class
- **Progressive Disclosure**: Dashboard shows summary; tapping shortcuts navigates to detail screens
- **Graceful Degradation**: Empty/loading/error states handled for every section

---

## 2. Architecture

### 2.1 Widget Tree Diagram

```
AppShell (from router ShellRoute)
  AppHeader (profile icon | "Home" | bell)
  HomeScreen (ConsumerStatefulWidget)  <-- THIS IS WHAT WE REDESIGN
    RefreshIndicator
      ListView(padding: EdgeInsets.all(20))
        _GreetingSection
        SizedBox(height: 12)
        _HashtagChips
        SizedBox(height: 28)
        _QuickShortcutGrid
        SizedBox(height: 28)
        _AnnouncementBanner
        SizedBox(height: 20)
  BottomNav (Home | Checklist | Tasks | Notices)
```

### 2.2 Data Flow

```
Riverpod Providers (already loaded)
  authProvider.user         --> _GreetingSection (firstName)
  assignmentProvider        --> _HashtagChips (store names, shift names)
  taskProvider              --> _AnnouncementBanner (due-today count)
  DateTime.now()            --> _GreetingSection (time-of-day greeting)
```

### 2.3 Dependencies

| Component | Depends On | Purpose |
|-----------|-----------|---------|
| `_GreetingSection` | `authProvider` | User's first name for greeting |
| `_HashtagChips` | `assignmentProvider` | Today's assignment store/shift tags |
| `_QuickShortcutGrid` | `GoRouter (context)` | Navigation to shortcut routes |
| `_AnnouncementBanner` | `taskProvider`, `authProvider` | Due-today task count, user name |

---

## 3. Component Specifications

### 3.1 _GreetingSection

**Purpose**: Display a time-of-day greeting with the user's first name.

**Data Mapping**:
- `user.firstName ?? 'Staff'` from `authProvider`
- `DateTime.now().hour` to determine greeting text

**Greeting Logic**:
```dart
String _getGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}
```

**Visual Spec**:
```
+-----------------------------------------------+
|  Good morning,                                 |
|  Sungmin                                       |
+-----------------------------------------------+
```

| Property | Value |
|----------|-------|
| "Good morning," | fontSize: 22, fontWeight: w400, color: AppColors.textSecondary |
| User name | fontSize: 28, fontWeight: w800, color: AppColors.text |
| Padding | None (inherits from parent ListView padding: 20) |

**Widget Structure**:
```dart
class _GreetingSection extends StatelessWidget {
  final String greeting;   // "Good morning"
  final String firstName;  // "Sungmin"

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$greeting,', style: ...),
        const SizedBox(height: 2),
        Text(firstName, style: ...),
      ],
    );
  }
}
```

---

### 3.2 _HashtagChips

**Purpose**: Show hashtag-style chips derived from today's assignment data.

**Data Mapping**:
- From `assignmentProvider.assignments`, extract:
  - Unique `store.name` values -> `#StoreName`
  - Unique `shift.name` values -> `#ShiftName`
- Example: assignments for store "Mbbq" with shift "open" -> `#Mbbq`, `#open`
- If no assignments, show nothing (hidden)

**Tag Extraction Logic**:
```dart
List<String> _extractTags(List<Assignment> assignments) {
  final tags = <String>{};
  for (final a in assignments) {
    if (a.store.name.isNotEmpty) tags.add(a.store.name);
    if (a.shift.name.isNotEmpty) tags.add(a.shift.name);
  }
  return tags.toList();
}
```

**Visual Spec**:
```
+-----------------------------------------------+
|  [#Mbbq]  [#open]                             |
+-----------------------------------------------+
```

| Property | Value |
|----------|-------|
| Chip background | AppColors.accentBg (0xFFF0EEFF) |
| Chip text | fontSize: 13, fontWeight: w600, color: AppColors.accent |
| Chip padding | horizontal: 12, vertical: 6 |
| Chip border radius | 16 |
| Chip spacing (horizontal) | 8 |
| Container | `Wrap` widget with spacing: 8 |

**Widget Structure**:
```dart
class _HashtagChips extends StatelessWidget {
  final List<String> tags;  // ["Mbbq", "open"]

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      children: tags.map((tag) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.accentBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text('#$tag', style: ...),
      )).toList(),
    );
  }
}
```

---

### 3.3 _QuickShortcutGrid

**Purpose**: 4-button horizontal grid for quick navigation.

**Shortcut Definitions**:

| Index | Label | Icon | Route | Status |
|-------|-------|------|-------|--------|
| 0 | mytask | Icons.assignment_outlined | `/work` | Active (navigates) |
| 1 | Clock In Out | Icons.access_time_outlined | N/A | Placeholder (toast) |
| 2 | Schedule | Icons.calendar_today_outlined | N/A | Placeholder (toast) |
| 3 | OJT | Icons.school_outlined | N/A | Placeholder (toast) |

**Visual Spec**:
```
+----------+----------+----------+----------+
|  [icon]  |  [icon]  |  [icon]  |  [icon]  |
|  mytask  | Clock In |Schedule  |   OJT    |
|          |   Out    |          |          |
+----------+----------+----------+----------+
```

| Property | Value |
|----------|-------|
| Grid container | White card with border (AppColors.border), borderRadius: 16, padding: 16 |
| Icon container | 48x48, backgroundColor: AppColors.bg (0xFFF5F6FA), borderRadius: 12 |
| Icon | size: 24, color: AppColors.accent |
| Label | fontSize: 11, fontWeight: w500, color: AppColors.textSecondary, textAlign: center, maxLines: 2 |
| Spacing (icon to label) | 8 |
| Layout | Row with 4 Expanded children |
| Tap area | Entire column for each shortcut (InkWell/GestureDetector) |

**Widget Structure**:
```dart
class _QuickShortcutGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: _shortcuts.map((s) => Expanded(
          child: _ShortcutButton(
            icon: s.icon,
            label: s.label,
            onTap: s.onTap,
          ),
        )).toList(),
      ),
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: AppColors.accent),
          ),
          const SizedBox(height: 8),
          Text(label, style: ..., textAlign: TextAlign.center, maxLines: 2),
        ],
      ),
    );
  }
}
```

---

### 3.4 _AnnouncementBanner

**Purpose**: Speech-bubble-style card showing an actionable reminder about due-today tasks.

**Data Mapping**:
- From `taskProvider.tasks`, count tasks where `dueDate` is today (same calendar day as `DateTime.now()`)
- From `authProvider.user`, get `fullName` for personalization
- If due-today count > 0: "[firstName] [lastName], you have [N] task(s) due today."
- If due-today count == 0: "[firstName], you're all caught up today!"

**Due-Today Count Logic**:
```dart
int _countDueToday(List<AdditionalTask> tasks) {
  final now = DateTime.now();
  return tasks.where((t) {
    if (t.dueDate == null) return false;
    return t.dueDate!.year == now.year
        && t.dueDate!.month == now.month
        && t.dueDate!.day == now.day;
  }).where((t) => t.status != 'completed').length;
}
```

**Visual Spec**:
```
+-----------------------------------------------+
|  [speech bubble icon]                          |
|  Sungmin Park, you have 3 task(s) due today.  |
|  Please check and complete them.               |
+-----------------------------------------------+
     \  (small triangle pointer at bottom-left)
```

| Property | Value |
|----------|-------|
| Card background | AppColors.accentBg (0xFFF0EEFF) |
| Card border | none |
| Card borderRadius | 16 |
| Card padding | 20 |
| Icon | Icons.campaign_outlined (or Icons.chat_bubble_outline), size: 20, color: AppColors.accent |
| Primary text | fontSize: 14, fontWeight: w600, color: AppColors.text |
| Secondary text | fontSize: 13, fontWeight: w400, color: AppColors.textSecondary |
| Triangle pointer | Optional -- can be implemented with `CustomPaint` or a rotated `Container`. If too complex, omit. |
| Tap action | Navigate to `/tasks` |

**Widget Structure**:
```dart
class _AnnouncementBanner extends StatelessWidget {
  final String message;
  final String subMessage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.accentBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.campaign_outlined, size: 20, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: ...),
                  const SizedBox(height: 4),
                  Text(subMessage, style: ...),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 4. Data Model

### 4.1 Existing Models (No Changes Required)

All data is sourced from existing models. No new models are needed.

| Model | Used Fields | Source Provider |
|-------|-------------|----------------|
| `User` | `firstName`, `lastName`, `fullName` | `authProvider` |
| `Assignment` | `store.name`, `shift.name` | `assignmentProvider` |
| `AdditionalTask` | `dueDate`, `status` | `taskProvider` |

### 4.2 Derived Data (Computed in Widget)

| Derived Value | Computation | Used By |
|---------------|-------------|---------|
| `greeting` | `DateTime.now().hour` -> "Good morning/afternoon/evening" | `_GreetingSection` |
| `tags` | Unique `store.name` + `shift.name` from assignments | `_HashtagChips` |
| `dueTodayCount` | Count tasks with `dueDate == today` and `status != completed` | `_AnnouncementBanner` |
| `bannerMessage` | Template string with `fullName` and `dueTodayCount` | `_AnnouncementBanner` |

---

## 5. API Specification

No new API endpoints required. All data comes from existing providers that call:

| Provider | Service Method | API Endpoint |
|----------|---------------|--------------|
| `assignmentProvider` | `loadAssignments(workDate)` | `GET /app/my/work-assignments?work_date=YYYY-MM-DD` |
| `taskProvider` | `loadTasks()` | `GET /app/my/tasks` |
| `authProvider` | (already loaded at app start) | `GET /app/auth/me` |

---

## 6. Screen Layout (Full Spec)

### 6.1 Complete Screen Wireframe

```
+-----------------------------------------------+
| [avatar] |      Home       | [bell badge]     |  <-- AppHeader (NOT modified)
+-----------------------------------------------+
|                                                |
|  Good morning,                                 |
|  Sungmin                                       |  <-- _GreetingSection
|                                                |
|  [#Mbbq]  [#open]                             |  <-- _HashtagChips
|                                                |
|  +-------------------------------------------+ |
|  |  [icon]    [icon]    [icon]    [icon]     | |
|  |  mytask  ClockInOut Schedule    OJT       | |  <-- _QuickShortcutGrid
|  +-------------------------------------------+ |
|                                                |
|  +-------------------------------------------+ |
|  | [megaphone] Sungmin Park, you have        | |
|  |  3 task(s) due today.                     | |  <-- _AnnouncementBanner
|  |  Please check and complete them.          | |
|  +-------------------------------------------+ |
|                                                |
+-----------------------------------------------+
| [Home*]  [Checklist]  [Tasks]  [Notices]       |  <-- BottomNav (NOT modified)
+-----------------------------------------------+
```

### 6.2 Responsive Behavior

| Viewport Width | Behavior |
|----------------|----------|
| < 360px | Shortcut labels may wrap to 2 lines (maxLines: 2) |
| 360px - 768px | Standard layout, no changes |
| > 768px | Content centered with max-width constraint (optional future enhancement) |

---

## 7. State Management

### 7.1 Provider Usage in HomeScreen

```dart
// Watched providers (reactive)
final user = ref.watch(authProvider).user;
final assignments = ref.watch(assignmentProvider);
final tasks = ref.watch(taskProvider);

// No new providers needed
// All computation is done locally in the build method or helper functions
```

### 7.2 initState Data Loading (Unchanged)

```dart
@override
void initState() {
  super.initState();
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  Future.microtask(() {
    ref.read(assignmentProvider.notifier).loadAssignments(today);
    ref.read(taskProvider.notifier).loadTasks();
    // Announcements no longer needed on home screen, but load for
    // potential future use or other screens
    ref.read(announcementProvider.notifier).loadAnnouncements();
  });
}
```

### 7.3 Pull-to-Refresh (Unchanged)

```dart
onRefresh: () async {
  final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
  await Future.wait([
    ref.read(assignmentProvider.notifier).loadAssignments(dateStr),
    ref.read(taskProvider.notifier).loadTasks(),
    ref.read(announcementProvider.notifier).loadAnnouncements(),
  ]);
}
```

---

## 8. Error Handling

### 8.1 Loading States

| Section | Loading Behavior |
|---------|-----------------|
| `_GreetingSection` | Always renders (uses `user?.firstName ?? 'Staff'`) |
| `_HashtagChips` | Hidden when `assignments.isLoading` or `assignments.isEmpty` |
| `_QuickShortcutGrid` | Always renders (static data, no loading state) |
| `_AnnouncementBanner` | Shows generic message when `tasks.isLoading` ("Check your tasks for today") |

### 8.2 Error States

| Provider Error | Behavior |
|----------------|----------|
| `assignmentProvider.error` | Hide chips, no visual error on home (errors shown on Work screen) |
| `taskProvider.error` | Banner shows generic message |
| `authProvider.user == null` | Greeting says "Good morning, Staff" |

---

## 9. Color and Style Specifications

### 9.1 Color Usage Map

| Element | Color Constant | Hex |
|---------|---------------|-----|
| Screen background | (inherited from AppShell) | AppColors.white |
| Greeting "Good morning," | AppColors.textSecondary | #6B7280 |
| Greeting user name | AppColors.text | #1A1D2E |
| Chip background | AppColors.accentBg | #F0EEFF |
| Chip text | AppColors.accent | #6C5CE7 |
| Shortcut card background | AppColors.white | #FFFFFF |
| Shortcut card border | AppColors.border | #E8EAF0 |
| Shortcut icon background | AppColors.bg | #F5F6FA |
| Shortcut icon color | AppColors.accent | #6C5CE7 |
| Shortcut label | AppColors.textSecondary | #6B7280 |
| Banner background | AppColors.accentBg | #F0EEFF |
| Banner icon | AppColors.accent | #6C5CE7 |
| Banner primary text | AppColors.text | #1A1D2E |
| Banner secondary text | AppColors.textSecondary | #6B7280 |

### 9.2 Typography Map

| Element | Size | Weight | Family |
|---------|------|--------|--------|
| Greeting prefix ("Good morning,") | 22 | w400 | DMSans |
| Greeting name | 28 | w800 | DMSans |
| Hashtag chip | 13 | w600 | DMSans |
| Shortcut label | 11 | w500 | DMSans |
| Banner primary text | 14 | w600 | DMSans |
| Banner secondary text | 13 | w400 | DMSans |

### 9.3 Spacing Map

| Gap | Value |
|-----|-------|
| ListView padding | 20 all sides |
| Greeting to chips | 12 |
| Chips to shortcut grid | 28 |
| Shortcut grid to banner | 28 |
| Banner to bottom | 20 |
| Inside shortcut card | vertical: 16, horizontal: 8 |
| Shortcut icon to label | 8 |
| Inside banner | 20 all sides |
| Banner icon to text | 12 |

---

## 10. Clean Architecture Layer Assignment

| Component | Layer | Location |
|-----------|-------|----------|
| `HomeScreen` | Presentation | `lib/screens/home/home_screen.dart` |
| `_GreetingSection` | Presentation (private) | Same file |
| `_HashtagChips` | Presentation (private) | Same file |
| `_QuickShortcutGrid` | Presentation (private) | Same file |
| `_ShortcutButton` | Presentation (private) | Same file |
| `_AnnouncementBanner` | Presentation (private) | Same file |
| `_getGreeting()` | Presentation (helper) | Same file (top-level function or method) |
| `_extractTags()` | Presentation (helper) | Same file |
| `_countDueToday()` | Presentation (helper) | Same file |

No changes to Application, Domain, or Infrastructure layers.

---

## 11. Coding Convention Reference

### 11.1 Conventions Applied

| Item | Convention |
|------|-----------|
| Widget naming | Private with `_` prefix (`_GreetingSection`, `_HashtagChips`) |
| File organization | All private widgets in same file (under 400 lines) |
| State management | `ref.watch` for reactive, `ref.read` in callbacks |
| Error handling | Graceful fallbacks, no error snackbars on home |
| Colors | `AppColors.*` constants only |
| Constructors | `const` wherever possible |

### 11.2 Import Requirements

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/assignment_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/announcement_provider.dart';
// NOTE: date_utils import may be removed if no longer used
```

---

## 12. Implementation Guide

### 12.1 File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/screens/home/home_screen.dart` | **Replace** | Rewrite with new layout (4 private widgets + helpers) |

No other files need modification. The AppShell, AppHeader, BottomNav, router, providers, models, and services remain unchanged.

### 12.2 Implementation Order

1. [ ] **Step 1**: Create `_getGreeting()` helper function (time-of-day logic)
2. [ ] **Step 2**: Create `_extractTags()` helper function (assignment tag extraction)
3. [ ] **Step 3**: Create `_countDueToday()` helper function (task due-date counting)
4. [ ] **Step 4**: Implement `_GreetingSection` widget
5. [ ] **Step 5**: Implement `_HashtagChips` widget
6. [ ] **Step 6**: Implement `_ShortcutButton` widget (single button)
7. [ ] **Step 7**: Implement `_QuickShortcutGrid` widget (row of 4 buttons with shortcut data)
8. [ ] **Step 8**: Implement `_AnnouncementBanner` widget
9. [ ] **Step 9**: Rewrite `HomeScreen.build()` to compose all sections in ListView
10. [ ] **Step 10**: Preserve `initState` (data loading) and `RefreshIndicator` (pull-to-refresh)
11. [ ] **Step 11**: Remove old private widgets (`_SectionHeader`, `_EmptyCard`, `_AssignmentCard`, `_TaskCard`)
12. [ ] **Step 12**: Run `flutter analyze` and fix any issues
13. [ ] **Step 13**: Test in Chrome (visual verification + pull-to-refresh + shortcut taps)

### 12.3 Complete Build Method (Reference)

```dart
@override
Widget build(BuildContext context) {
  final user = ref.watch(authProvider).user;
  final assignments = ref.watch(assignmentProvider);
  final tasks = ref.watch(taskProvider);
  final today = DateTime.now();

  final greeting = _getGreeting();
  final firstName = user?.firstName ?? 'Staff';
  final tags = _extractTags(assignments.assignments);
  final dueTodayCount = _countDueToday(tasks.tasks);
  final fullName = user?.fullName ?? 'Staff';

  String bannerMessage;
  String bannerSub;
  if (dueTodayCount > 0) {
    bannerMessage = '$fullName, you have $dueTodayCount task(s) due today.';
    bannerSub = 'Please check and complete them.';
  } else {
    bannerMessage = '$firstName, you\'re all caught up today!';
    bannerSub = 'Great job keeping on top of things.';
  }

  return RefreshIndicator(
    onRefresh: () async { ... },
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _GreetingSection(greeting: greeting, firstName: firstName),
        const SizedBox(height: 12),
        if (!assignments.isLoading && tags.isNotEmpty)
          _HashtagChips(tags: tags),
        const SizedBox(height: 28),
        _QuickShortcutGrid(),
        const SizedBox(height: 28),
        _AnnouncementBanner(
          message: bannerMessage,
          subMessage: bannerSub,
          onTap: () => context.push('/tasks'),
        ),
        const SizedBox(height: 20),
      ],
    ),
  );
}
```

---

## 13. Test Plan

### 13.1 Test Scope

| Type | Target | Tool |
|------|--------|------|
| Manual | Visual layout matches design | Chrome DevTools |
| Manual | Pull-to-refresh works | Chrome |
| Manual | Shortcut taps navigate / show toast | Chrome |
| Manual | Greeting changes by time of day | Modify system clock or test method |
| Static | Zero lint errors | `flutter analyze` |
| Build | Web build succeeds | `flutter build web` |

### 13.2 Test Cases

- [ ] Happy path: user logged in, has assignments, has due-today tasks -> all sections render
- [ ] Empty assignments: chips section is hidden, greeting still shows
- [ ] No due-today tasks: banner shows "all caught up" message
- [ ] User has no firstName: greeting shows "Staff"
- [ ] Pull-to-refresh: spinner appears, data reloads
- [ ] Tap "mytask" shortcut: navigates to `/work`
- [ ] Tap "Clock In Out" shortcut: shows "Coming soon" toast
- [ ] Tap "Schedule" shortcut: shows "Coming soon" toast
- [ ] Tap "OJT" shortcut: shows "Coming soon" toast
- [ ] Tap announcement banner: navigates to `/tasks`
- [ ] Morning (before 12:00): "Good morning"
- [ ] Afternoon (12:00-16:59): "Good afternoon"
- [ ] Evening (17:00+): "Good evening"

---

## 14. Migration Notes

### 14.1 Removed Widgets (from old home_screen.dart)

The following private widgets from the current file will be deleted since they are not used elsewhere:

| Widget | Lines | Reason for Removal |
|--------|-------|--------------------|
| `_SectionHeader` | 211-249 | Replaced by greeting + chips |
| `_EmptyCard` | 251-272 | No longer needed |
| `_AssignmentCard` | 274-350 | Replaced by shortcut grid |
| `_TaskCard` | 352-450 | Replaced by announcement banner |

### 14.2 Preserved Code

| Code | Lines | Reason |
|------|-------|--------|
| `initState` data loading | 19-28 | Still needed for providers |
| `RefreshIndicator` + `onRefresh` | 38-46 | Pull-to-refresh preserved |
| Import list | 1-10 | Mostly the same (may drop `date_utils`) |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 0.1 | 2026-02-20 | Initial design | CTO Lead |
