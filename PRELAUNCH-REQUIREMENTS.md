# Pre-Launch Requirements — V1 (iPhone + iPad + Mac)
> Last updated: April 10, 2026
> Status: **V1 approved by Apple ✅. Waiting for Paid Apps Agreement (banking) before enabling themes + IAPs.**

---

## Overall Progress

| Area | Status | Notes |
|---|---|---|
| Core Note Features | ✅ Done | Editor, formatting, folders, checklists |
| Calendar Integration (Apple) | ✅ Done | Events sync, complete/delete removes events |
| Calendar Integration (Google) | ✅ Done | OAuth, multi-account, cleanup all working |
| Date Parsing | ✅ Done | "next Friday", "in 3 days", "EOD", bare weekdays |
| Widget System | ✅ Done | Fully compatible, theme syncs |
| Theme System | ✅ Done | 8 paid themes + 2 free themes. Menu + banner hidden until banking approved. |
| Export | ✅ Done | PDF + plain text share |
| Attachments | ✅ Done | Photos, files, scan |
| Reminders Import | ✅ Done | |
| Google Cloud Project | ✅ Done | Moved to "Dhakira" project |
| Paywall (StoreKit 2) | ✅ Done | $2.99/theme · $14.99 bundle · dev unlock |
| App Icon | ✅ Done | Set in Xcode |
| iPhone Screenshots | ✅ Done | 5 screenshots at 1320×2868 |
| iPad Screenshots | ✅ Done | 5 screenshots at 2064×2752 — need fresh screenshots with latest changes |
| Mac Screenshots | 🔲 Remaining | Need to take new screenshots from Mac Catalyst |
| Mac Catalyst Support | ✅ Done | Layout, sync, navigation, deletion, calendar, widgets |
| iCloud Settings Sync | ✅ Done | Theme, sort order, toolbar sync across devices |
| iCloud Task Sync | ✅ Done | SwiftData + CloudKit, works across iPhone/iPad/Mac |
| Landing Page | 🔲 Remaining | dhakira.app — domain purchased, page not built |
| Google OAuth Verification | ⚠️ In Progress | Verified from developer side, users may still see warning |
| iCloud Theme Ownership Gate | ✅ Done | ThemeRestoreGate blocks paid themes without ownership — PR #129 |
| Bug Fixes (PR #127) | ✅ Done | Font sizes, calendar dedup, sync race condition |
| CloudKit Production Schema | ✅ Done | Deployed to Production — existing users' data restored |
| App Store Submission (V1) | ✅ Approved | Apple approved V1. Waiting for banking to enable IAPs. |
| App Store Connect Banking | ⚠️ In Progress | Address submitted to Apple — awaiting Paid Apps Agreement approval |

---

## Design Decisions (Locked)

| Decision | Detail |
|----------|--------|
| Calendar sync direction | App → Calendar only. Deleting from Apple/Google Calendar does NOT affect tasks. App is the source of truth. |
| Free themes | `Bright Mode` + `Midnight` — always free |
| Paid themes | 8 MeshingKit themes — $2.99 each |
| Bundle | "Trending Bundle" — all 8 themes — $14.99 lifetime |
| Developer unlock | Type `yazeedjameel` in the theme search bar — unlocks all themes on device |
| Pricing (after Apple's 30%) | Single theme → you receive $2.09 · Bundle → you receive $10.49 |

---

## Priority 1 — Branding & Logo

### App Icon
| Slot | Status | Location |
|------|--------|----------|
| Icon file exists (1024×1024) | ✅ | `.playwright-mcp/dakira-icon-1024x1024.png` |
| Icon file exists (1024×1024) variant | ✅ | `.playwright-mcp/dakira-icon-4-D-spark-1024x1024.png` |
| Icon set in Xcode (`AppIcon.appiconset`) | ❌ **Not done** | Slot exists but no image assigned |

**Action needed:** Drag your chosen 1024×1024 PNG into Xcode → `Assets.xcassets → AppIcon`. No alpha channel, no rounded corners (Apple applies the mask automatically).

---

### App Store Screenshots — All 3 devices ready at `localhost:3005`

| Device | Size | Status | Export |
|--------|------|--------|--------|
| iPhone 6.9" | 1320×2868 | ✅ 5 ready | iPhone tab → Export All 5 |
| iPad Pro 13" | 2064×2752 | ✅ 5 ready | iPad tab → Export All 5 |
| Mac | 2880×1800 | ✅ 5 ready | Mac tab → Export All 5 |

All 5 screens across all devices:
1. Task List
2. Rich Editor
3. Folders
4. Calendar Month
5. Calendar Day

**Action needed:** Go to `localhost:3005`, click each tab, hit "Export All 5" to download the files, then upload to App Store Connect.

---

## Priority 2 — Landing Page (dhakira.app)

| # | Task | Status |
|---|------|--------|
| 1 | Domain purchased: dhakira.app | ✅ |
| 2 | Point domain to hosting (Cloudflare Pages or similar) | 🔲 |
| 3 | Build landing page (iOS-style, screenshots, App Store button) | 🔲 |
| 4 | Host privacy policy at dhakira.app/privacy-policy | 🔲 |
| 5 | Add App Store link once approved | 🔲 |

Privacy policy content is already written in `docs/privacy-policy.html` — just needs to be deployed.

---

## Priority 3 — Google OAuth Verification

Once dhakira.app is live:

| # | Step | Status |
|---|------|--------|
| 1 | Go to Google Cloud Console → Branding (`dhakira-492200`) | 🔲 |
| 2 | Set homepage: `https://dhakira.app` | 🔲 |
| 3 | Set privacy policy: `https://dhakira.app/privacy-policy` | 🔲 |
| 4 | Add authorized domain: `dhakira.app` | 🔲 |
| 5 | Click "Verify branding" (1–3 business days) | 🔲 |

Until verified: users see "This app isn't verified" warning but can proceed via Advanced → Go to Dhakira.

---

## Priority 4 — App Store Connect Setup

| # | Task | Status |
|---|------|--------|
| 1 | Fill in banking details (Agreements, Tax, and Banking) | ⚠️ In Progress — address submitted, awaiting Apple approval |
| 2 | Create 9 In-App Purchase products (Non-Consumable) | 🔲 After banking approved |
| 3 | 8 × `com.prodnote.theme.*` at $2.99 each | 🔲 After banking approved |
| 4 | 1 × `com.prodnote.theme.pro` (Trending Bundle) at $14.99 | 🔲 After banking approved |
| 5 | Re-enable Theme menu + Bundle banner in code (v1.3) | 🔲 After banking approved — un-comment in SettingsMenuView + ThemeView |
| 6 | Update screenshots (reflect latest UI changes) | 🔲 Before next submit |
| 7 | Write App Store description + keywords | 🔲 |
| 8 | Archive + upload via Xcode (Product → Archive) | 🔲 After all above done |
| 9 | Submit v1.1 / v1.3 for Apple Review | 🔲 |

---

## Testing Checklist (Run Before Submitting)

### StoreKit / Paywall
- [ ] Lock icon appears on all 8 paid theme cards
- [ ] "Unlock – $2.99" button appears on paid theme detail screen
- [ ] Tapping it shows Apple's native payment sheet
- [ ] After purchase, theme applies automatically
- [ ] Bundle banner shows in theme gallery
- [ ] "Get All" opens bundle sheet at $14.99
- [ ] Restore purchases works after reinstall
- [ ] Type `yazeedjameel` in theme search → all themes unlock instantly

### Calendar
- [x] Apple Calendar events created with 15-min reminder
- [x] Google Calendar events created via OAuth
- [x] Completing a task removes events from both calendars
- [x] Deleting a task removes events from both calendars
- [ ] Deep link in calendar event opens correct note (re-test)

### Device Testing
- [x] iPhone — working 10/10
- [x] iPad — working 10/10
- [x] Mac Catalyst — working (layout, sync, calendar, widgets, themes)
- [ ] iPhone SE — no layout breaks (verify)
- [ ] iPad Mini — layout check (verify)

---

## Mac Catalyst — What Was Done (April 7, 2026)

| Feature | Status |
|---------|--------|
| DataScanner excluded on Mac (camera-only API) | ✅ |
| Content width constrained (700-800pt), centered layout | ✅ |
| Minimum window size (540×600) | ✅ |
| Centered NSToolbar title ("Dhakira") | ✅ |
| Expanded button/checkbox hit areas for mouse | ✅ |
| Sidebar always visible (like Apple Notes) | ✅ |
| Right-click context menu (delete, priority, complete) | ✅ |
| iCloud KVS settings sync (theme, sort order, toolbar) | ✅ |
| iCloud KVS entitlement fixed (bundle ID mismatch) | ✅ |
| Theme sync across devices with foreground refresh | ✅ |
| Missing modelContext.save() in 6 deletion/restore functions | ✅ |
| CloudKit.framework explicitly linked | ✅ |
| Calendar sandbox entitlement added | ✅ |
| Widget URL scheme fixed (dhakira:// instead of prodnote://) | ✅ |
| Widget Mac Catalyst support enabled | ✅ |
| Bundle ID consistency (DERIVE_MACCATALYST = NO) | ✅ |
| Widget shows current task list only (not all folders) | ✅ |
| Cleaned stale LaunchServices registrations (simulator ghosts) | ✅ |
| Widget "Today" header padding fixed | ✅ |

---

## What's Left — Ordered by Priority

| Task | Priority | Blocked By |
|------|----------|------------|
| Apple approves Paid Apps Agreement (banking) | 🔴 Critical | Waiting on Apple |
| Re-enable theme menu + bundle banner in code | 🔴 Critical | Banking approval |
| Create 9 IAP products in App Store Connect | 🔴 Critical | Banking approval |
| Update screenshots (fresh UI) | 🟡 High | — |
| Take Mac screenshots (5 screens) | 🟡 High | — |
| Build landing page (dhakira.app) | 🟡 High | — |
| Google OAuth verification (dhakira.app) | 🟡 High | Landing page live |
| Archive + upload v1.1 build | 🟡 High | Banking + screenshots |
| Submit for Apple Review (v1.1) | 🟡 High | Archive done |

---

## Key Facts

| Item | Value |
|------|-------|
| App name | Dhakira |
| Bundle ID | `com.prodnote.notetaking` |
| Version | 1.0 build 1 |
| Deployment target | iOS 26.2 / macOS 15.6 |
| Platforms | iPhone, iPad, Mac (Catalyst) |
| Google Cloud project | `dhakira-492200` |
| Domain | dhakira.app |
| Development team | `2Q6SBYY55H` |
