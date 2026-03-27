# Interview: Simple Task/Reminder App
**Date:** 2026-03-26
**Status:** Complete

## Problem Statement
Existing productivity/task apps (Apple Reminders, Todoist, etc.) are overcomplicated — too many tabs, buttons, landing pages, and settings. Users just want a simple task list. Apple Reminders is functionally close but boring and uninspiring. The goal is to build a task app so simple that users need zero training — they already know what to expect from a task app.

## Target User
People who want dead-simple task management. Not power users who want Notion-level complexity. People who open an app, write a task, and close it.

## Success Criteria
- User opens app → immediately sees their tasks (no home page, no onboarding)
- Creating a task takes 1 tap
- Completing a task takes 1 tap
- No learning curve — it works like users already expect

## Core Philosophy
- Less buttons/controls = more freedom
- People already know what to expect from a task app — don't make them learn a new system
- Simplicity is the #1 priority, always
- Don't overcomplicate anything — ever
- Design should be appealing but not overly aesthetic or "clicky"

---

## Scope

### In Scope (MVP / v1)
- Task list (main screen — this IS the app)
- Task detail/editor page (Apple Notes-like markdown editor)
- Priority color markers (2-3 colors, tap to change)
- Basic text formatting (Bold, Italic, Underline, Strikethrough)
- Inline task creation (+ button, like Apple Reminders)
- Task completion (tap checkbox → strikethrough + fade → stored quietly)
- Swipe gestures (swipe right = indent/sub-task, swipe far right = delete)
- Auto date detection (dates typed in text → highlighted blue → synced to Apple Calendar)
- Auto-generated creation timestamp on each task
- Settings menu (gear icon on task list page): Sort By (creation date, priority) + Show Completed toggle + Theme entry point
- Theme: follows system dark/light mode automatically — no manual toggle needed in v1. Colors adapt accordingly
- iCloud sync (native — no accounts, no login, just works via Apple ID)
- Must work across: iPhone, iPad, Mac desktop, Apple Watch
- Siri integration via App Intents — "Hey Siri, create a task in [OurApp]" creates a task with voice. "Hey Siri, create a task with details: ..." populates both title and detail page body

### In Scope (v2)
- Folder organization (nestable, simple — like Apple Notes)
- Drawing/handwriting tools (pen, pencil, highlighter, eraser, color picker)
- Attachments (scan text, scan docs, photo/video, record audio, attach file)
- Tables support
- Checklists (sub-checklists within a task detail)
- Paragraph tools (indent, outdent, move up/down, block quote, bullet lists)
- Search functionality (only if users request it)

### Out of Scope
- Home page / landing page
- Multiple tabs or navigation complexity
- Calendar view
- User accounts / login / sign-up
- Payment / subscription walls
- Push notifications
- Complex settings screens
- App naming / branding / marketing (comes at the end, pre-launch phase)

---

## User Flow

### Happy Path
1. Open app → **Task List** screen appears immediately
2. Tap **+** (bottom right) → new task row appears inline
3. Type task text directly in the list
4. Tap the **color marker** (small square) → pick priority (2-3 colors: e.g., red = urgent, yellow = medium, gray = default)
5. Tap **"..."** under a task → opens **Task Detail** page
6. Task Detail shows: back arrow, auto-date, share button, checkmark (hide toolbar), markdown editor with formatting tools
7. **Keyboard toolbar** appears above keyboard when typing — tools ordered by most recently used (MRU on left)
8. Tap back arrow → returns to Task List (not a home page, just back)
9. Tap **checkbox** on left side of a task → task gets strikethrough, fades, disappears from list (stored somewhere quietly)
10. (v2) Tap **top-left arrow** from task list → Folders screen — create, organize, nest folders, recently deleted

### Swipe Gestures
- Swipe right → indent task (becomes sub-task of task above)
- Swipe far right → delete task

---

## Edge Cases
- Empty state: first-time user sees empty task list with just the + button — clean and inviting
- Completed tasks: disappear from active list, stored quietly (no big "Completed" section, no metadata noise)
- Date detection: if user types "March 30" or "April 10th" in task text, auto-highlight in blue and sync to Apple Calendar silently (no notification)
- No dates forced: dates are completely optional, never enforced
- Sub-tasks via indentation: swipe right to nest under parent task

---

## Technical Context

### Platform
- iOS (SwiftUI) for MVP
- Possibly Flutter later for cross-platform (iOS, Android, desktop)

### Data Storage
- iCloud sync preferred — native, seamless, no account creation required
- No login page, no sign-up — just works with user's existing Apple ID
- Must research best approach for native iCloud sync (CloudKit, SwiftData, etc.)

### Design Direction
- Dark theme (off-white accents, low brightness)
- Modern but not flashy — glassmorphism elements where appropriate (2026 trends)
- Must feel familiar — users should recognize patterns from Apple Notes/Reminders
- Use native iOS libraries for editor tools wherever possible (don't rebuild what exists)

### Editor Toolbar (from Apple Notes reference screenshots)
- **Aa** — text formatting (B, I, U, S)
- **Checklist** — checked/unchecked circles
- **Table** — simple grid tables
- **Attachment (paperclip)** — scan text, scan docs, photo/video, audio, file
- **Markup (circled A)** — drawing tools (pen, crayon, fountain pen, brush, fine tip, pencil, highlighter, eraser + color picker)
- **Paragraph** — indent, outdent, move up/down, block quote, bullet list
- **Smart ordering**: most recently used tools appear first (leftmost) in the keyboard toolbar

### Key Instruction from User
> "Learn before you code. Search, read documentation, understand what 2026 has to offer. Don't build blindly. You don't know as many libraries as you think."

### Constraints
- No user accounts or authentication
- No payment walls
- No push notifications (dates sync to calendar silently)
- Must feel native iOS — not a web wrapper

---

## Priority
- **Level:** High
- **MVP (v1):** Task list + detail editor + priority colors + basic text formatting + date detection + swipe gestures
- **Deferred (v2):** Folders, drawing tools, attachments, tables, checklists, paragraph tools, search
- **Deferred (pre-launch):** App naming, branding, domain, marketing

---

## Reference Screenshots on File
| File | What It Shows |
|------|---------------|
| `apple-reminders_context-menu.jpg` | Reminders list options (columns, sort, sections, templates) |
| `apple-reminders_home-screen.PNG` | Reminders home layout (Today, Scheduled, All, Flagged, etc.) |
| `apple-notes_editor-view.png` | Notes editor with auto-date, toolbar, formatting |
| `apple-notes_checklist-icon.jpg` | Checklist toggle icon |
| `apple-notes_table-and-toolbar.jpg` | Table + full toolbar bar |
| `apple-notes_attachment-icon.jpg` | Paperclip attachment icon |
| `apple-notes_attachment-menu.jpg` | Full attachment options menu |
| `apple-notes_markup-icon.jpg` | Markup/drawing icon |
| `apple-notes_drawing-tools-set1.jpg` | Drawing tools (pen, crayon, fountain, brush, tip) |
| `apple-notes_drawing-tools-set2.jpg` | Drawing tools (pencil, fine pen, highlighter, eraser) |
| `apple-notes_text-formatting-BIUS.jpg` | Bold, Italic, Underline, Strikethrough |
| `apple-notes_paragraph-indent-list.jpg` | Indent, outdent, move, block quote, bullet list |
| `handwritten_task-list-wireframe.HEIC` | Hand-drawn wireframe of task list UI |

## Settings Menu (Gear Icon — Task List Page)

| Option | Description | Version |
|--------|-------------|---------|
| Sort By | Sort tasks by creation date or priority color | v1 |
| Show Completed | Toggle to reveal/hide completed tasks | v1 |
| Theme | Opens dedicated theme/customization page — **future monetization feature** | v1 skeleton, v2+ full |

### Theme — Monetization Strategy (Future)
- Theme page = the money-making machine
- Will include: full app customization, widget styling, color schemes, accent colors
- Needs research: what widget types exist on iOS, how customizable are they, what can be sold
- For v1: theme follows system (dark/light) automatically — no manual override needed
- For v2+: premium themes, custom accent colors, widget skins — this is where revenue comes from

### Multi-Device Support
- iPhone (primary)
- iPad
- Mac desktop
- Apple Watch
- All synced via iCloud natively

## Raw Notes
- User is not a designer — expects guidance on UI/UX decisions
- User emphasizes: "don't overcomplicate it" — repeated multiple times
- User wants to research libraries and frameworks before any coding begins
- Requirements file renamed to "PRELAUNCH-REQUIREMENTS.md" and should be broken into sub/micro-requirements
- Completed tasks should be stored but not displayed prominently — "most of the time people don't care about their completed tasks"
- The keyboard toolbar smart ordering (MRU tools first) is a differentiator from Apple Notes
- Don't add features that users already know how to do natively (e.g., multi-select is just iOS behavior)
- CRITICAL: Research extensively before coding. Find the best, newest libraries. Critique them. Share links. Collaborate on choosing tools — not just build blindly
- App must work with system theme — dark phone = dark app, light phone = light app. Colors must adapt (e.g., white text can't appear on white background)
