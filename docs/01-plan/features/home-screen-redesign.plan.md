# home-screen-redesign Planning Document

> **Summary**: Redesign the Home screen from a data-listing layout to a personalized dashboard with greeting, hashtag chips, quick-shortcut grid, and announcement banner.
>
> **Project**: Employee Management Service (Flutter Web)
> **Version**: 1.0.0
> **Author**: CTO Lead
> **Date**: 2026-02-20
> **Status**: Draft

---

## 1. Overview

### 1.1 Purpose

Replace the current home screen -- which is a vertically stacked list of assignment cards, task cards, and notice cards -- with a modern, personalized dashboard layout. The new design emphasizes:

- A time-of-day-based greeting with the user's first name
- Hashtag chips representing today's assignments (brand/shift tags)
- A 4-button quick-shortcut grid for primary navigation (mytask, Clock In Out, Schedule, OJT)
- A speech-bubble-style announcement banner surfacing urgent/due-today reminders

### 1.2 Background

The current home screen (451 lines, ConsumerStatefulWidget) displays three stacked sections: Today's Work (assignment cards with progress bars), Tasks (task cards with priority indicators), and Recent Notices (announcement list). While functional, this layout does not provide a quick glanceable summary and lacks personality. The redesign consolidates key information into fewer, more impactful visual blocks and adds shortcut-based navigation to reduce taps.

### 1.3 Related Documents

- Design: `docs/02-design/features/home-screen-redesign.design.md`
- Current implementation: `lib/screens/home/home_screen.dart`
- App shell and header: `lib/widgets/app_shell.dart`, `lib/widgets/app_header.dart`
- Providers: `lib/providers/auth_provider.dart`, `lib/providers/assignment_provider.dart`, `lib/providers/task_provider.dart`, `lib/providers/announcement_provider.dart`

---

## 2. Scope

### 2.1 In Scope

- [x] Remove old home screen sections (assignment cards, task cards, notice cards)
- [x] Add time-of-day greeting ("Good morning / Good afternoon / Good evening")
- [x] Add hashtag chips derived from today's assignments (store name, shift name)
- [x] Add 4-button quick-shortcut grid (mytask, Clock In Out, Schedule, OJT)
- [x] Add announcement/reminder banner in speech-bubble style
- [x] Derive banner message from due-today tasks count
- [x] Maintain pull-to-refresh behavior
- [x] Keep existing data loading from Riverpod providers (auth, assignment, task, announcement)
- [x] Work within existing AppShell (header stays as-is; the home screen content is what changes)

### 2.2 Out of Scope

- Modifying the AppHeader widget (profile icon | title | bell) -- it stays as-is
- Modifying the BottomNav widget -- it stays as-is
- Adding new backend API endpoints
- Implementing "Clock In Out", "Schedule", or "OJT" screens (these shortcuts will navigate to placeholder or existing routes)
- Dark mode support
- Localization (i18n) -- strings will be hardcoded English for now
- Animations / micro-interactions beyond basic transitions

---

## 3. Requirements

### 3.1 Functional Requirements

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| FR-01 | Display time-of-day greeting with user's first name (fallback: "Staff") | High | Pending |
| FR-02 | Show hashtag chips from today's assignments (unique store names + shift names) | High | Pending |
| FR-03 | Render 4-button shortcut grid with icon placeholders and labels | High | Pending |
| FR-04 | Show speech-bubble announcement banner with due-today task count | Medium | Pending |
| FR-05 | "mytask" shortcut navigates to `/work` | High | Pending |
| FR-06 | "Clock In Out" shortcut shows placeholder/toast (no screen yet) | Low | Pending |
| FR-07 | "Schedule" shortcut shows placeholder/toast (no screen yet) | Low | Pending |
| FR-08 | "OJT" shortcut shows placeholder/toast (no screen yet) | Low | Pending |
| FR-09 | Pull-to-refresh reloads all provider data | High | Pending |
| FR-10 | Banner tap navigates to `/tasks` | Medium | Pending |

### 3.2 Non-Functional Requirements

| Category | Criteria | Measurement Method |
|----------|----------|-------------------|
| Performance | Home screen renders within 16ms frame budget (no jank) | Flutter DevTools |
| Responsiveness | Layout adapts to 320px-768px viewport width | Manual testing on Chrome |
| Accessibility | All interactive elements have tap targets >= 44px | Manual audit |
| Code Quality | Widget file stays under 400 lines; extract private widgets | Line count |

---

## 4. Success Criteria

### 4.1 Definition of Done

- [x] New home screen matches the target design layout
- [x] All 4 shortcut buttons are visible and tappable
- [x] Greeting updates based on time of day
- [x] Hashtag chips are dynamically derived from assignment data
- [x] Announcement banner displays due-today count from task data
- [x] Pull-to-refresh works
- [x] Existing providers are reused (no new services/models)
- [x] Code review completed
- [x] Flutter analyze passes with zero errors

### 4.2 Quality Criteria

- [x] Zero lint errors (`flutter analyze`)
- [x] Build succeeds (`flutter build web`)
- [x] No regressions on other screens (router, shell, auth)

---

## 5. Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Shortcut routes not yet implemented (Clock In Out, Schedule, OJT) | Low | High | Show toast "Coming soon" on tap for unimplemented routes |
| User has no assignments for the day (empty chips) | Medium | Medium | Hide chips section or show "No assignments today" fallback |
| Task due-date data may be null | Medium | Medium | Guard with null check; show generic "Check your tasks" if no due-today tasks |
| Time-of-day greeting could confuse users in different timezones | Low | Low | Use device local time (DateTime.now()), which is standard for mobile |

---

## 6. Architecture Considerations

### 6.1 Project Level

This is a Flutter Web app using clean architecture with Riverpod state management. The project fits the **Dynamic** level: feature-based modules, BaaS-like backend integration.

### 6.2 Key Architectural Decisions

| Decision | Options | Selected | Rationale |
|----------|---------|----------|-----------|
| Greeting logic | Static "Hello" / Time-based | Time-based | Target design specifies "Good morning" |
| Chip data source | Hardcoded / From assignments | From assignments | Dynamic, reflects actual daily work |
| Shortcut grid | New routes / Placeholders | Placeholders (toast) | Only `/work` has a real screen; others TBD |
| Banner data source | Static / From task due dates | From task due dates | Dynamic, actionable reminders |
| Speech bubble style | CustomPainter / Container with decoration | Container with decoration | Simpler, sufficient for the shape |

### 6.3 Widget Tree (High Level)

```
HomeScreen (ConsumerStatefulWidget)
  RefreshIndicator
    ListView (padding: 20)
      _GreetingSection         -> user firstName, time of day
      SizedBox(height: 12)
      _HashtagChips            -> derived from assignments
      SizedBox(height: 24)
      _QuickShortcutGrid       -> 4 buttons in a row
      SizedBox(height: 24)
      _AnnouncementBanner      -> speech bubble, due-today count
```

---

## 7. Convention Prerequisites

### 7.1 Existing Project Conventions

- [x] `CLAUDE.md` has coding conventions section
- [x] `analysis_options.yaml` exists
- [x] Riverpod StateNotifierProvider pattern established
- [x] GoRouter routing with auth redirect

### 7.2 Conventions to Follow

| Category | Convention |
|----------|-----------|
| Naming | snake_case.dart files, PascalCase classes, camelCase methods |
| State | Use `ref.watch` for reactive data, `ref.read` for one-time actions |
| Widgets | Private widgets prefixed with `_`, use const constructors |
| Imports | Relative imports within lib/, package imports first |
| Colors | Use `AppColors.*` constants from `config/theme.dart` |

---

## 8. Next Steps

1. [x] Write design document (`home-screen-redesign.design.md`)
2. [ ] Team review and approval
3. [ ] Start implementation (Do phase)

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 0.1 | 2026-02-20 | Initial draft | CTO Lead |
