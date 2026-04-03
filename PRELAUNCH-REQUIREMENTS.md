# Pre-Launch Requirements — V1 (iPhone + iPad)
> Last updated: April 2, 2026
> Status: **Google Calendar done, branding & submission remaining**

---

## Overall Progress

| Area | Status | Notes |
|---|---|---|
| Core Note Features | ✅ Done | Editor, formatting, folders all working |
| Calendar Integration (Apple) | ✅ Done | Events sync, complete/delete removes events |
| Calendar Integration (Google) | ✅ Done | OAuth, multi-account, cleanup all working |
| Date Parsing | ✅ Done | "next Friday" vs "this Friday", "in 3 days", "EOD", bare weekdays |
| Widget System | ✅ Done | Fully compatible, theme syncs |
| Theme System | ✅ Done | Applies across app and widgets |
| Export | ✅ Done | PDF + plain text share |
| Attachments | ✅ Done | Photos, files, scan |
| Reminders Import | ✅ Done | |
| Google Cloud Project | ✅ Done | Moved from "strictseal" to "Dhakira" project |
| More Themes (paid) | 🔲 Remaining | Need to add more theme designs |
| Paywall | 🔲 Remaining | StoreKit integration |
| Branding + Logo | 🔲 Remaining | App icon, screens |
| Landing Page | 🔲 Remaining | dhakira.app domain purchased, page not built |
| Google OAuth Verification | 🔲 Remaining | Needs branding page with privacy policy URL |
| App Store Submission | 🔲 Remaining | License, listing, review |

---

## Google Calendar — Completed

### What Was Done
| # | Task | Status |
|---|------|--------|
| 1 | Created new Google Cloud project "Dhakira" (`dhakira-492200`) | ✅ |
| 2 | Enabled Google Calendar API | ✅ |
| 3 | Created iOS OAuth client (bundle ID: `com.prodnote.notetaking`) | ✅ |
| 4 | Updated app code with new Client ID | ✅ |
| 5 | Updated Info.plist URL scheme | ✅ |
| 6 | OAuth consent screen configured (External, published) | ✅ |
| 7 | UI shows "Connected" / "Sign in with Google" with proper feedback | ✅ |
| 8 | Events sync to Google Calendar on task creation | ✅ |
| 9 | Events removed on task completion or deletion | ✅ |
| 10 | Events cleaned up on app launch for completed/trashed tasks | ✅ |
| 11 | Account switch detection (email-based) | ✅ |
| 12 | Events deleted from old account on disconnect | ✅ |
| 13 | Reinstall detection (Keychain vs UserDefaults mismatch) | ✅ |
| 14 | Apple Calendar targets iCloud (not Gmail CalDAV) | ✅ |
| 15 | KeychainHelper has error logging | ✅ |
| 16 | "next Friday" vs "this Friday" resolved correctly | ✅ |
| 17 | Privacy policy page created (`docs/privacy-policy.html`) | ✅ |

### Google OAuth Verification — Remaining Steps

| # | Step | Status | Notes |
|---|------|--------|-------|
| 1 | Build landing page at dhakira.app | 🔲 | Domain purchased, page not built yet |
| 2 | Host privacy policy at dhakira.app/privacy-policy | 🔲 | Content already written in `docs/privacy-policy.html` |
| 3 | Go to Google Cloud Console → Branding page | 🔲 | Fill in homepage + privacy policy URLs |
| 4 | Click "Verify branding" | 🔲 | Google reviews branding (not a full app review) |
| 5 | Data access scopes are non-sensitive | ✅ | No security review required |

**Temporary workaround:** Until verified, users see "This app isn't verified" warning during sign-in but can click "Advanced → Go to Dhakira (unsafe)" to proceed. Fully functional.

---

## Priority 1 — Testing (Do This Repeatedly Until Launch)

### Core Note Features
- [x] Create, edit, format notes (bold, italic, lists, quotes, checklists)
- [x] Slash menu works
- [x] Drag-to-reorder toolbar

### Folders & Navigation
- [x] Create, rename, delete folders
- [x] Navigate between views smoothly

### Calendar & Date Detection
- [x] Dates auto-detected in task titles
- [x] Apple Calendar events created with correct time
- [x] Google Calendar events created via OAuth
- [x] Events have 15-minute reminder
- [x] "next Friday" → next week's Friday, "this Friday" → this week's Friday
- [x] "in 3 days", "in 2 weeks", "EOD", "tonight" all work
- [x] Completing a task removes events from both calendars
- [x] Deleting a task removes events from both calendars
- [x] Un-completing a task re-creates events
- [x] Account switch clears old events, syncs fresh to new account
- [x] App reinstall forces re-sign-in (no stale "Connected" state)
- [ ] Deep link in calendar event opens the app at the correct note (re-test)

### Export & Attachments
- [x] PDF export with images, dark theme text fix
- [x] Plain text share
- [x] Photos, files, scan attachments work

### Edge Cases
- [x] Delete a note with calendar event → event removed
- [x] Calendar permission denied → app handles gracefully (no crash)
- [x] CloudKit restores completed task → events cleaned up on launch
- [ ] Note title with two dates → uses earliest (verify)
- [ ] Widget loads with no notes → no crash (verify)
- [ ] Force-quit mid-edit → no data loss (verify)
- [ ] VoiceOver accessibility (verify)

### Device Testing
- [ ] iPhone 17 Pro — Light + Dark mode
- [ ] iPhone SE (small screen) — no layout breaks
- [ ] iPad Pro 13" — split view, slide over
- [ ] iPad Mini — layout check

---

## Priority 2 — More Themes (Revenue Driver)

| Name | Tier | Status |
|---|---|---|
| Default | Free | ✅ Done |
| Midnight | Free | ✅ Done |
| Academia | Paid | 🔲 |
| Nord | Paid | 🔲 |
| Tokyo Night | Paid | 🔲 |
| Forest | Paid | 🔲 |
| Rose | Paid | 🔲 |
| Void | Paid (bundle) | 🔲 |

---

## Priority 3 — Paywall (StoreKit)
- [ ] Free tier: Default + Midnight only
- [ ] Paid theme pricing locked
- [ ] StoreKit 2 integration
- [ ] Purchase flow tested in sandbox
- [ ] Restore purchases works

---

## Priority 4 — Landing Page (dhakira.app)

| # | Task | Status |
|---|------|--------|
| 1 | Domain purchased: dhakira.app | ✅ |
| 2 | Point domain to hosting (Cloudflare Pages or similar) | 🔲 |
| 3 | Build landing page (iOS-style, screenshots, download button) | 🔲 |
| 4 | Host privacy policy at dhakira.app/privacy-policy | 🔲 |
| 5 | Add App Store link once approved | 🔲 |

**Privacy policy content is already written** in `docs/privacy-policy.html` — just needs to be deployed to the domain.

---

## Priority 5 — Google OAuth Branding Verification

Once dhakira.app is live with the privacy policy:
1. Go to [Google Cloud Console → Branding](https://console.cloud.google.com/auth/branding?project=dhakira-492200)
2. Fill in:
   - Application home page: `https://dhakira.app`
   - Privacy policy link: `https://dhakira.app/privacy-policy`
3. Add authorized domain: `dhakira.app`
4. Click "Save" then "Verify branding"
5. Google reviews (usually 1-3 business days for non-sensitive scopes)

After verification: the "unverified app" warning disappears for all users.

---

## Priority 6 — Branding & Screenshots
- [x] App name: Dhakira
- [x] Domain: dhakira.app
- [ ] Logo (1024x1024)
- [ ] App Store screenshots (5 per device)
- [ ] Screenshot devices: iPhone 6.9", iPad Pro 13"

---

## Priority 7 — App Store Submission
- [ ] App Store description written
- [ ] Keywords researched
- [ ] Version 1.0.0, Build 1
- [ ] Archive + upload via Xcode
- [ ] App Store Connect listing complete
- [ ] Submit for Apple Review

---

## Key Files Modified (Google Calendar Sprint)

| File | What Changed |
|---|---|
| `Services/GoogleAuthService.swift` | New Dhakira client ID, email scope, account detection, validate on launch |
| `Services/GoogleCalendarAPIService.swift` | Fixed HTTP 400 (removed dhakira:// source), added timeZone, error body logging |
| `Services/CalendarSyncService.swift` | iCloud calendar targeting, cleanup on startup, delete-all on disconnect, resync |
| `Services/CalendarSelectionService.swift` | Observable hasGoogleCalendar, logging, EventKit refresh |
| `Services/DateDetectionService.swift` | "next" vs "this" weekday, bare weekdays, "in N days/weeks", EOD/EOW/EOM |
| `Services/KeychainHelper.swift` | Error handling + logging for save/delete |
| `Views/HomeView.swift` | Removed Local Google Calendar, proper connect/disconnect flow |
| `Views/TaskListView.swift` | Calendar cleanup on complete/uncomplete, CloudKit reconciliation cleanup |
| `Note_takingApp.swift` | Startup cleanup, validate tokens, email backfill |
| `Info.plist` | New OAuth URL scheme |
| `docs/privacy-policy.html` | Privacy policy for Google verification |
| `docs/index.html` | Simple homepage |
