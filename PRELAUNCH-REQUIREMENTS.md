# Pre-Launch Requirements — V1 (iPhone + iPad + Mac)
> Last updated: April 13, 2026
> Status: **Ready to ship. All blockers cleared. App is 100% free — no IAPs, no paywall.**

---

## Overall Progress

| Area | Status | Notes |
|---|---|---|
| Core Note Features | ✅ Done | Editor, formatting, folders, checklists |
| Calendar Integration (Apple) | ✅ Done | Events sync, complete/delete removes events |
| Calendar Integration (Google) | ✅ Done | OAuth verified and approved by Google |
| Date Parsing | ✅ Done | "next Friday", "in 3 days", "EOD", bare weekdays |
| Widget System | ✅ Done | Fully compatible, theme syncs |
| Theme System | ✅ Done | All 10 themes free. No paywall, no lock icons, no purchase flow. |
| Export | ✅ Done | PDF + plain text share |
| Attachments | ✅ Done | Photos, files, scan |
| Reminders Import | ✅ Done | |
| Google Cloud Project | ✅ Done | Moved to "Dhakira" project, OAuth verified |
| Google OAuth Verification | ✅ Done | Approved — no more "unverified app" warning |
| App Icon | ✅ Done | Set in Xcode |
| iPhone Screenshots | ✅ Done | 5 screenshots at 1320×2868 |
| iPad Screenshots | ✅ Done | 5 screenshots at 2064×2752 |
| Mac Catalyst Support | ✅ Done | Layout, sync, navigation, deletion, calendar, widgets |
| iCloud Settings Sync | ✅ Done | Theme, sort order, toolbar sync across devices |
| iCloud Task Sync | ✅ Done | SwiftData + CloudKit, works across iPhone/iPad/Mac |
| Landing Page | ✅ Done | dhakira.app is live |
| CloudKit Production Schema | ✅ Done | Deployed to Production |
| App Store Submission (V1) | ✅ Approved | Apple approved V1 |
| Folder Reordering | ✅ Done | Native DropDelegate drag-to-reorder |
| Undo/Redo (Folder Page) | ✅ Done | Native SwiftData undo via modelContext.undoManager |
| Checkbox Hit Area (Mac) | ✅ Done | Enlarged to 44×44 for Mac Catalyst |
| Empty Page Navigation | ✅ Done | Back button on empty Recently Completed/Deleted |

---

## Business Model

| Decision | Detail |
|----------|--------|
| Pricing | **Free** — no purchases, no paywall, no subscriptions |
| All themes | Free — all 10 themes available to every user |
| Future monetization | TBD — possibly custom themes, pro features, or one-time purchase later |
| StoreKit infrastructure | Still in codebase, dormant. Flip `isOwned()` back when ready. |
| Developer unlock | Disabled in release builds (`#if DEBUG` guard) |

---

## What's Left — Ship It

| Task | Priority | Status |
|------|----------|--------|
| Archive + upload new build in Xcode | 🔴 Do now | Ready |
| Submit for Apple Review | 🔴 Do now | After archive |
| Update screenshots if needed (reflect free themes, folder changes) | 🟡 Optional | Current screenshots may still be accurate |
| Mac screenshots (5 screens) | 🟡 Optional | Nice to have for Mac App Store listing |

---

## What Was Done — April 13, 2026

| Change | Detail |
|--------|--------|
| Free themes | Removed all paywalls — `isOwned()` always returns true, lock icons deleted, paywall sheet removed |
| Folder reordering | Added `sortOrder` to Folder model, native DropDelegate for drag-to-reorder |
| Folder page UX | Add Folder/Add List styled as lighter action buttons, context menu delete |
| Back button fix | Recently Completed and Recently Deleted show back button when empty |
| Mac checkbox | Tap target enlarged from 28×28 to 44×44 for Mac Catalyst |
| Theme button | Re-enabled in settings menu (was hidden for IAP wait) |
| Undo/redo | Native SwiftData undo on folder page via `modelContext.undoManager` |
| Developer passphrase | Guarded behind `#if DEBUG` — disabled in release builds |

---

## Testing Checklist (Run Before Submitting)

### Themes
- [ ] All 10 themes show in gallery with no lock icons
- [ ] Tapping any theme shows "Apply" button (no purchase prompt)
- [ ] Theme applies immediately on tap
- [ ] Theme button visible in settings menu (... button)

### Folders
- [ ] Long-press folder → context menu → Delete works
- [ ] Long-press folder → Rename works
- [ ] Drag folder over another folder → positions swap
- [ ] Add Folder button is visually lighter than folder rows
- [ ] Undo/redo buttons work after rename or reorder

### Calendar
- [x] Apple Calendar events created with 15-min reminder
- [x] Google Calendar events created via OAuth (now verified)
- [x] Completing a task removes events from both calendars
- [x] Deleting a task removes events from both calendars

### Navigation
- [ ] Recently Completed (empty) → back button visible and works
- [ ] Recently Deleted (empty) → back button visible and works

### Device Testing
- [x] iPhone — working
- [x] iPad — working
- [x] Mac Catalyst — working

---

## Key Facts

| Item | Value |
|------|-------|
| App name | Dhakira |
| Bundle ID | `com.prodnote.notetaking` |
| Version | 1.4 |
| Deployment target | iOS 26.2 / macOS 15.6 |
| Platforms | iPhone, iPad, Mac (Catalyst) |
| Google Cloud project | `dhakira-492200` |
| Domain | dhakira.app |
| Development team | `2Q6SBYY55H` |
| Monetization | Free (StoreKit infrastructure dormant, ready to re-enable) |
