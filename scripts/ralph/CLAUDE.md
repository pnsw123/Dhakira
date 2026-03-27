# Ralph Agent Instructions

You are an autonomous coding agent building a SwiftUI task/reminder app.

## Your Process (Every Iteration)

1. Read `scripts/ralph/prd.json` to find the highest-priority incomplete story (where `"status": "pending"`)
2. Read `scripts/ralph/progress.txt` for context from previous iterations
3. Read `tasks/research-report.md` for technology decisions and design guidelines
4. Read `tasks/prd-task-app.md` for full product requirements
5. Implement the story — create/modify files as needed
6. Build the project to verify: `xcodebuild -project Note-taking.xcodeproj -scheme Note-taking -destination 'platform=macOS,arch=arm64' build 2>&1 | grep -E "error:|BUILD"`
7. If build fails, fix the errors and rebuild until it passes
8. Update `scripts/ralph/prd.json` — set the completed story's status to `"completed"`
9. Append progress to `scripts/ralph/progress.txt`
10. If ALL stories have status "completed", reply with `<promise>COMPLETE</promise>`

## Critical Rules

- **ONE story per iteration** — do not try to implement multiple stories at once
- **Build after every change** — verify compilation before marking complete
- **Reference Apple documentation** — never trust training data for API names or function signatures. Use WebSearch or WebFetch to verify against developer.apple.com before coding
- **Follow the design** — this is a card-based UI, NOT a flat list. Each task is a rectangle/card with a color marker tab on the top-left like a notebook bookmark
- **SF Symbols only** — use Apple's SF Symbols for ALL icons (6,900+ available). No custom icons
- **Semantic colors** — never hardcode Color.white, Color.black. Use Color.primary, Color.secondary, Color(.systemBackground)
- **Apple HIG spacing** — 16-20pt margins, 8pt between items, 44x44pt minimum tap targets, SF Pro 17pt body text
- **SwiftData CloudKit rules** — all properties need defaults or be optional, no @Attribute(.unique), relationships optional

## Tech Stack

| Component | Tool |
|-----------|------|
| UI | SwiftUI (iOS 26+) |
| Rich Text Editor | MarkupEditor (Swift Package) |
| Drawing | PencilKit (native) |
| Data + Sync | SwiftData + CloudKit |
| Date Detection | NSDataDetector |
| Calendar Sync | EventKit |
| Reminders Import | EventKit (EKReminder) |
| Siri | App Intents + Assistant Schemas |
| Icons | SF Symbols 7 |
| Design | Liquid Glass (iOS 26) |

## Project Structure

```
Note-taking/
├── Models/         — SwiftData @Model files (Task, Attachment, Folder)
├── Views/          — SwiftUI views (TaskListView, TaskRowView, TaskDetailView)
├── Extensions/     — Color+App.swift and other extensions
├── Services/       — DateDetectionService, CalendarSyncService, RemindersImportService
├── Intents/        — App Intents for Siri integration
└── Assets.xcassets — Colors (PriorityHigh, PriorityMedium, PriorityDefault)
```

## Design Direction

- Modern but not flashy — Liquid Glass where appropriate
- Card-based task list — each task is a rounded rectangle with depth
- Color marker as a vertical tab/bookmark on the left side of each card
- Dark/light mode follows system automatically
- Must feel like a native Apple app — not a web wrapper
- Simplicity is #1 priority — less buttons = more freedom

## Progress File Format

Append this to progress.txt after each story:

```
## Story [ID]: [Title]
- Status: COMPLETED
- Files changed: [list]
- Build: PASSED
- Learnings: [any gotchas or patterns discovered]
- Date: [timestamp]
---
```
