# PRD: Simple Task/Reminder App
**Version:** 1.0
**Date:** 2026-03-26
**Status:** Draft — Pending Approval
**Source:** `tasks/interview-task-app.md`, `tasks/research-report.md`

---

## 1. Overview

A dead-simple, creative, productive task/reminder app for iOS. Existing task apps are overcomplicated — too many tabs, buttons, and screens. This app solves that: open it, see your tasks, create one in a single tap, done.

**Business Value:** Free app with monetization through premium themes and widget customization (v2+). The simplicity is the product.

### Core Philosophy (Non-Negotiable)

| Principle | What It Means |
|-----------|--------------|
| Less buttons = more freedom | Every button must earn its place. If iOS already handles it natively, don't add it |
| No learning curve | Users already know what to expect from a task app — don't make them learn a new system |
| Simplicity is #1 | When in doubt, don't add it |
| Must feel native iOS | Not a web wrapper, not a cross-platform port — must feel like an Apple app |
| Don't recreate the wheel | Use existing frameworks, SF Symbols, native tools. Nothing custom unless absolutely necessary |
| Productivity & UX = 99.99% | The app is about user experience, not technical cleverness |

### Design Constraints

| Constraint | Reason |
|-----------|--------|
| No user accounts | iCloud handles identity |
| No payment walls | Free app, monetize through themes |
| No push notifications | Calendar handles its own reminders |
| No onboarding | Users don't need training |
| Icons: SF Symbols only | No custom icons, no emojis |
| Must feel native iOS | Not a web wrapper — must feel like Apple built it |

---

## 2. Goals

| Goal | Metric |
|------|--------|
| Zero learning curve | First task created within 10 seconds of opening the app |
| Minimal UI | Maximum 3 screens: Task List → Task Detail → Folders |
| Speed | App launch to task list in under 1 second |
| Cross-device sync | Seamless across iPhone, iPad, Mac, Apple Watch via iCloud |
| Voice-first | Siri creates tasks naturally ("remind me to...") without naming the app |
| No accounts | Zero login, zero sign-up — works with existing Apple ID |

---

## 3. User Stories (INVEST-Compliant)

### Epic 1: Task List (Main Screen)

**US-1.1: View Task List**
```
As a user,
I want to see all my tasks immediately when I open the app,
So that I don't waste time navigating.

Acceptance Criteria:
- [ ] App opens directly to the task list — no splash, no onboarding, no home page
- [ ] Each task shows: title text, priority color marker (small square), "..." below
- [ ] Tasks displayed in a scrollable list
- [ ] Empty state: just the "+" button — clean and inviting
```

**US-1.2: Create Task Inline**
```
As a user,
I want to tap "+" to instantly create a new task,
So that adding tasks is as fast as possible.

Acceptance Criteria:
- [ ] "+" button at bottom right of task list
- [ ] Tapping "+" creates a new task row inline (like Apple Reminders)
- [ ] Cursor focuses for immediate typing
- [ ] New task starts with gray (default) priority marker
- [ ] Tap area: 44x44pt minimum (Apple HIG)
```

**US-1.3: Complete Task**
```
As a user,
I want to tap a checkbox to mark a task as done,
So that completed tasks don't clutter my list.

Acceptance Criteria:
- [ ] Checkbox/circle on the left side of each task
- [ ] Tap: strikethrough → fade → disappears from active list
- [ ] Completed task stored quietly (accessible via "Show Completed" toggle)
- [ ] Smooth animation (fade + strikethrough)
- [ ] Haptic feedback on completion
```

**US-1.4: Set Priority Color**
```
As a user,
I want to tap the color marker to set task priority,
So that I can visually distinguish urgent tasks.

Acceptance Criteria:
- [ ] Tap marker square → small picker with 3 colors
- [ ] Colors: Red (urgent), Orange (medium), Gray (default)
- [ ] Tap area: 44x44pt minimum
- [ ] Color changes immediately, no confirmation
- [ ] Colors in Asset Catalog with light + dark variants
```

**US-1.5: Swipe Gestures**
```
As a user,
I want to swipe tasks for quick actions,
So that I can organize and delete efficiently.

Acceptance Criteria:
- [ ] Swipe right → indent task (becomes sub-task of task above)
- [ ] Swipe far right → delete task
- [ ] Smooth, native-feeling animations
- [ ] Indented tasks visually nested with padding
```

**US-1.6: Settings Menu**
```
As a user,
I want settings accessible from the task list,
So that I can sort tasks and manage preferences.

Acceptance Criteria:
- [ ] Gear icon (SF Symbol: gearshape) top-right area
- [ ] Dropdown menu: Sort By, Show Completed, Theme
- [ ] Sort By: Creation Date, Priority
- [ ] Show Completed: toggle visibility of completed tasks
- [ ] Theme: entry point for v2 customization/monetization
```

---

### Epic 2: Task Detail Page

**US-2.1: Open Task Detail**
```
As a user,
I want to tap "..." on a task to see its full detail page,
So that I can add notes, formatting, and rich content.

Acceptance Criteria:
- [ ] Tapping "..." opens Task Detail page
- [ ] Shows: back arrow (top-left), auto-date, share button, checkmark (hide/show toolbar)
- [ ] Back arrow returns to Task List (not a home page)
- [ ] Auto-date format: "26 March 2026 at 5:45PM"
```

**US-2.2: Rich Text Editor & Toolbar**
```
As a user,
I want a rich text editor with formatting tools,
So that I can organize my task details with structure.

Acceptance Criteria:
- [ ] Editor powered by MarkupEditor (WYSIWYG, WKWebView + ProseMirror)

Toolbar buttons (6 tools, matching Apple Notes layout):
- [ ] Aa (textformat) — opens: Bold, Italic, Underline, Strikethrough
- [ ] Checklist (checklist) — toggle checked/unchecked circles
- [ ] Table (tablecells) — insert/edit simple grid tables
- [ ] Attachment (paperclip) — opens attachment menu (see US-2.5)
- [ ] Markup (pencil.tip.crop.circle) — opens PencilKit drawing (see US-2.3)
- [ ] Paragraph (list.bullet) — indent, outdent, move up/down, block quote, bullet list

Additional formatting:
- [ ] Supports: Headings (H1-H6), numbered lists, links, images
- [ ] Keyboard toolbar appears above keyboard when typing
- [ ] Toolbar ordered by Most Recently Used (MRU on left) — KEY DIFFERENTIATOR
- [ ] Most recently used tool moves to leftmost position on next keyboard open
```

**US-2.5: Attachments**
```
As a user,
I want to attach files, photos, and audio to my tasks,
So that I can capture rich context for each task.

Acceptance Criteria:
- [ ] Paperclip icon (SF Symbol: paperclip) in toolbar
- [ ] Tapping opens attachment menu with options:
  - [ ] Scan Text (Live Text / VisionKit)
  - [ ] Scan Documents (VNDocumentCameraViewController)
  - [ ] Take Photo or Video (UIImagePickerController / camera)
  - [ ] Choose Photo or Video (PHPickerViewController)
  - [ ] Record Audio (AVAudioRecorder)
  - [ ] Attach File (UIDocumentPickerViewController)
- [ ] Attachments embedded in task detail body
- [ ] Attachments saved in SwiftData and synced via iCloud
```

**US-2.6: Share & Toolbar Toggle**
```
As a user,
I want to share my task and hide the toolbar when not needed,
So that I have a clean editing experience.

Acceptance Criteria:
- [ ] Share button (SF Symbol: square.and.arrow.up) in top bar of detail page
- [ ] Uses native iOS share sheet (UIActivityViewController)
- [ ] Checkmark button (SF Symbol: checkmark.circle) in top bar
- [ ] Tapping checkmark hides/shows the formatting toolbar
- [ ] Toolbar state persists while editing the same task
```

**US-2.3: Drawing/Handwriting**
```
As a user,
I want to draw or handwrite in my task details,
So that I can sketch ideas or write with Apple Pencil.

Acceptance Criteria:
- [ ] Markup icon (SF Symbol: pencil.tip.crop.circle) in toolbar
- [ ] Opens PencilKit canvas with PKToolPicker
- [ ] Tools: pen, pencil, marker, highlighter, eraser, color picker, ruler
- [ ] Works with Apple Pencil (iPad) and finger (iPhone)
- [ ] Drawings saved as PKDrawing data in SwiftData
- [ ] Drawings sync via iCloud
```

**US-2.4: Date Detection & Calendar Sync**
```
As a user,
I want dates I type to be automatically detected and synced to my calendar,
So that I don't manually create calendar events.

Acceptance Criteria:
- [ ] NSDataDetector scans text as user types (debounced ~300ms)
- [ ] Detected dates highlighted in blue (Color.accentColor)
- [ ] Dates silently create event in Apple Calendar via EventKit
- [ ] No push notifications — calendar handles its own reminders
- [ ] Permission: NSCalendarsFullAccessUsageDescription in Info.plist
- [ ] Graceful degradation if permission denied (dates highlighted, no sync)
- [ ] Duplicate prevention: store eventIdentifier locally
```

---

### Epic 3: Data & Sync

**US-3.1: Data Model**
```
As a developer,
I want a clean SwiftData model,
So that tasks persist and sync correctly.

Acceptance Criteria:
- [ ] Task @Model: id (UUID = UUID()), title (String = ""), body (Data? = nil),
      priority (String = "default"), isCompleted (Bool = false),
      createdAt (Date = Date()), completedAt (Date? = nil),
      parentTask (Task? = nil), folder (Folder? = nil),
      drawingData (Data? = nil), calendarEventId (String? = nil),
      attachments ([Attachment]? = nil)
- [ ] Attachment @Model: id (UUID = UUID()), type (String = ""),
      data (Data? = nil), fileName (String? = nil),
      createdAt (Date = Date()), task (Task? = nil)
- [ ] All properties have defaults or are optional (CloudKit requirement)
- [ ] No @Attribute(.unique) — UUID handles identity
- [ ] Relationships are optional
```

**US-3.2: iCloud Sync**
```
As a user,
I want my tasks synced across all my Apple devices,
So that I can access them anywhere.

Acceptance Criteria:
- [ ] SwiftData + CloudKit with cloudKitDatabase: .automatic
- [ ] iCloud capability + CloudKit container configured
- [ ] Background Modes + Remote Notifications enabled
- [ ] No login, no sign-up — uses device Apple ID
- [ ] Works offline, syncs when back online
- [ ] Test on real devices (simulator sync unreliable)
- [ ] Call initializeCloudKitSchema() for schema sync
```

---

### Epic 4: Siri Integration

**US-4.1: Siri via App Intents**
```
As a user,
I want to create tasks using Siri with our app name,
So that I can voice-create tasks from any device.

Acceptance Criteria:
- [ ] AppIntent struct defines "Create Task" action
- [ ] Adopts Assistant Schema for flexible natural language
- [ ] Siri captures title → creates task in SwiftData
- [ ] Optional: captures "details" → populates task body
- [ ] Works on iPhone, iPad, Mac, Apple Watch
- [ ] Reference WWDC24/25 docs during implementation — never hardcode phrases
```

**US-4.2: Siri via Apple Reminders Auto-Import**
```
As a user,
I want to say "Hey Siri, remind me to..." and have it appear in this app,
So that I can use natural voice commands without naming the app.

Acceptance Criteria:
- [ ] Settings toggle: "Import from Siri & Apple Reminders"
- [ ] App requests Reminders access (NSRemindersFullAccessUsageDescription)
- [ ] App watches for new Apple Reminders via EventKit (EKReminder)
- [ ] New reminders auto-imported as tasks within seconds
- [ ] Optional: auto-delete Apple Reminder after import
- [ ] User says "Hey Siri, remind me to buy groceries" → appears in our app
- [ ] Works on Apple Watch, iPhone, iPad, Mac
```

---

### Epic 5: Multi-Device

**US-5.1: iPad & Mac**
```
As a user,
I want the app on iPad and Mac,
So that I can manage tasks from any Apple device.

Acceptance Criteria:
- [ ] SwiftUI multiplatform target (iOS + macOS)
- [ ] Layout adapts to larger screens
- [ ] Same SwiftData model, same iCloud sync
- [ ] Mac: keyboard shortcuts, menu bar items
```

**US-5.2: Apple Watch**
```
As a user,
I want to view and complete tasks on my Apple Watch,
So that I can manage tasks from my wrist.

Acceptance Criteria:
- [ ] watchOS target with SwiftUI
- [ ] Simplified task list view
- [ ] Tap to mark task complete
- [ ] Syncs via shared SwiftData + CloudKit
- [ ] TextFieldLink for text input
```

---

### Epic 6: Theme & Appearance

**US-6.1: System Theme**
```
As a user,
I want the app to match my device's dark/light mode,
So that it looks natural alongside my other apps.

Acceptance Criteria:
- [ ] Follows system appearance automatically
- [ ] Semantic colors: Color.primary, Color.secondary, Color(.systemBackground)
- [ ] Priority colors in Asset Catalog with light + dark variants
- [ ] Never hardcode Color.white, Color.black, Color.gray
- [ ] Liquid Glass effects on navigation elements (automatic with iOS 26)
```

**US-6.2: Theme Page Skeleton**
```
As a user,
I want a Theme page in settings,
So that I know customization is coming.

Acceptance Criteria:
- [ ] Theme option in settings gear menu
- [ ] Opens placeholder page: "Themes coming soon"
- [ ] UI skeleton ready for v2 monetization
```

---

### Epic 7: Widgets (v2)

**US-7.1: Home Screen Widget**
```
As a user,
I want a widget showing my tasks on my home screen,
So that I can see and complete tasks without opening the app.

Acceptance Criteria:
- [ ] WidgetKit with AppIntents for interactivity
- [ ] Small, Medium, Large sizes
- [ ] Shows tasks with priority colors
- [ ] Tap checkbox on widget → marks complete (no app launch)
- [ ] Adapts to dark/light mode
```

---

### Epic 8: Folders (v2)

**US-8.1: Folder Organization**
```
As a user,
I want to organize tasks into folders,
So that I can group related tasks.

Acceptance Criteria:
- [ ] Folder screen via top-left arrow from task list
- [ ] Create, rename, delete folders
- [ ] Nestable folders (simple UX)
- [ ] Recently Deleted folder
- [ ] Move tasks between folders
```

---

## 3b. Edge Cases & Empty States

| Scenario | Expected Behavior |
|----------|------------------|
| First-time user (no tasks) | Empty list with just the "+" button — clean, inviting, no onboarding |
| Completed task | Strikethrough + fade → disappears from active list. Stored quietly, visible via "Show Completed" toggle |
| Date typed in text | Auto-detected, highlighted blue. Silently synced to Apple Calendar. No notification |
| No date in task | Nothing happens — dates are never forced or required |
| Sub-task (indented) | Swipe right to nest under parent task. Visually indented |
| Calendar permission denied | Dates still highlighted blue, but no calendar sync. App works fully otherwise |
| Reminders permission denied | Siri auto-import disabled. App Intents (direct Siri) still works |
| iCloud not signed in | App works locally. Syncs when user signs into iCloud |
| Offline usage | Full functionality. Syncs when back online |
| Task with no title | Allowed — user can have a task that's just a detail page with rich content |

---

## 4. Technical Requirements

### Tech Stack

| Component | Tool | Type |
|-----------|------|------|
| UI | SwiftUI (iOS 26+) | Native |
| Rich Text Editor | MarkupEditor | Third-party (1 dependency) |
| Drawing | PencilKit | Native |
| Data + Sync | SwiftData + CloudKit | Native |
| Date Detection | NSDataDetector | Native |
| Calendar Sync | EventKit | Native |
| Reminders Import | EventKit (EKReminder) | Native |
| Siri | App Intents + Assistant Schemas | Native |
| Icons | SF Symbols 7 (6,900+) | Native |
| Design | Liquid Glass (iOS 26) | Native |
| Widgets | WidgetKit + AppIntents | Native |

### Dependencies: 1 third-party (MarkupEditor), 11 native Apple frameworks

### Design Rules (Apple HIG)

| Rule | Value |
|------|-------|
| Screen margins | 16-20pt |
| Between list items | 8pt |
| Card padding | 12-16pt |
| Min tap target | 44x44pt |
| Body text | SF Pro 17pt |
| Subtitles | SF Pro 13pt |
| Headers | SF Pro Bold 20-22pt |

---

## 5. Success Criteria

| Metric | Target |
|--------|--------|
| Time to first task | < 10 seconds |
| Task creation | 1 tap |
| Task completion | 1 tap |
| App launch | < 1 second |
| iCloud sync | < 30 seconds |
| Siri "remind me" import | < 10 seconds |
| App size | < 30MB |

---

## 6. Out of Scope

| Item | Reason |
|------|--------|
| Home page / landing page | Open = see tasks |
| User accounts / login | iCloud handles identity |
| Push notifications | Calendar handles reminders |
| Payment walls | Free app, themes monetize later |
| Search | v2 if users request |
| Calendar view | Not a calendar app |
| App naming / branding | Pre-launch phase |
| Android / Flutter | After iOS success |

---

## 7. Implementation Plan

### Phase 1: Foundation
| Task | Stories | Priority |
|------|---------|----------|
| SwiftData model (Task) | US-3.1 | Critical |
| Task List screen | US-1.1, US-1.2, US-1.3 | Critical |
| Priority colors | US-1.4 | Critical |
| Swipe gestures | US-1.5 | High |
| Settings menu | US-1.6 | High |
| System theme | US-6.1 | High |

### Phase 2: Detail Page
| Task | Stories | Priority |
|------|---------|----------|
| Task Detail navigation | US-2.1 | Critical |
| MarkupEditor integration + toolbar (6 buttons) | US-2.2 | Critical |
| PencilKit drawing | US-2.3 | High |
| Date detection + highlight | US-2.4 | High |
| Calendar sync | US-2.4 | High |
| Attachments (scan, photo, audio, file) | US-2.5 | High |
| Share button + toolbar toggle | US-2.6 | Medium |

### Phase 3: Sync & Devices
| Task | Stories | Priority |
|------|---------|----------|
| iCloud sync | US-3.2 | Critical |
| iPad support | US-5.1 | High |
| Mac support | US-5.1 | Medium |
| Apple Watch | US-5.2 | Medium |

### Phase 4: Voice & Intelligence
| Task | Stories | Priority |
|------|---------|----------|
| App Intents (Siri direct) | US-4.1 | High |
| Reminders auto-import (Siri natural) | US-4.2 | High |
| Theme page skeleton | US-6.2 | Low |

### Phase 5: v2
| Task | Stories | Priority |
|------|---------|----------|
| Folders | US-8.1 | High |
| Widgets | US-7.1 | High |
| Premium themes | — | Medium |
| Search | — | Low |

---

## 8. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| MarkupEditor doesn't meet needs | Medium | High | Evaluate before integrating. Fallback: custom SwiftUI views |
| iCloud sync issues | Medium | High | Test on real devices. Use initializeCloudKitSchema() |
| Calendar permission denied | Medium | Low | Graceful degradation — dates highlighted, no sync |
| Reminders permission denied | Medium | Medium | Siri auto-import disabled, direct App Intents still works |
| iOS 26 minimum | Low | Medium | Target audience uses modern devices |
| Siri integration complexity | Medium | Medium | Study WWDC sessions. Reference docs, not training data |

---

## 9. Documentation References

| Resource | When to Use |
|----------|-------------|
| [Apple HIG: Layout](https://developer.apple.com/design/human-interface-guidelines/layout) | All UI work |
| [WWDC25: Rich text + AttributedString](https://developer.apple.com/videos/play/wwdc2025/280/) | Editor features |
| [WWDC25: Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/323/) | Design |
| [WWDC25: SF Symbols 7](https://developer.apple.com/videos/play/wwdc2025/337/) | Icons |
| [WWDC25: App Intents](https://developer.apple.com/videos/play/wwdc2025/244/) | Siri |
| [WWDC24: Bring app to Siri](https://developer.apple.com/videos/play/wwdc2024/10133/) | Siri + Apple Intelligence |
| [Apple: SwiftData + CloudKit](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices) | iCloud sync |
| [Apple: EventKit](https://developer.apple.com/documentation/eventkit) | Calendar + Reminders |
| [Apple: PencilKit](https://developer.apple.com/documentation/pencilkit) | Drawing |
| [MarkupEditor (GitHub)](https://github.com/stevengharris/MarkupEditor) | Rich text editor |
| [Any.do Siri integration](https://support.any.do/en/articles/8634346-any-do-siri-apple-reminders) | Reminders auto-import pattern |

---

**CRITICAL RULE:** Before implementing ANY feature, verify all API names, signatures, and capabilities against official Apple documentation. Never rely on LLM training data for API details.
