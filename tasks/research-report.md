# Research Report: Libraries, Tools & Technology Stack
**Date:** 2026-03-26
**Status:** Complete

---

## 1. Rich Text Editor (Task Detail Page)

This is the most critical library decision. We need Apple Notes-like editing with formatting toolbar.

### Option A: Native SwiftUI TextEditor + AttributedString (iOS 26)

| Aspect | Details |
|--------|---------|
| **What** | Apple's own TextEditor now supports rich text via AttributedString in iOS 26 |
| **WWDC 2025** | Session "Cook up a rich text experience in SwiftUI with AttributedString" |
| **Features** | Bold, italic, underline, strikethrough, custom fonts, colors, paragraph styling, Genmoji |
| **Pros** | Zero dependencies, native, future-proof, no maintenance burden, free |
| **Cons** | Requires iOS 26 minimum, newer API (less community examples) |
| **Verdict** | **RECOMMENDED for our app** — since we're building new, targeting iOS 26 is fine |

Sources:
- [WWDC25 Code-along: Rich text with AttributedString](https://developer.apple.com/videos/play/wwdc2025/280/)
- [Apple Docs: Building rich SwiftUI text experiences](https://developer.apple.com/documentation/swiftui/building-rich-swiftui-text-experiences)
- [HackingWithSwift: Rich text editing tutorial](https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-rich-text-editing-with-textview-and-attributedstring)
- [Real-Time Pattern Detector with iOS 26 TextEditor](https://dimillian.medium.com/building-a-real-time-pattern-detector-with-ios-26s-texteditor-and-attributedstring-07c0f7b88e32)

### Option B: RichTextKit (Daniel Saidi)

| Aspect | Details |
|--------|---------|
| **Stars** | 1,300 |
| **Last update** | v1.2 — April 2025 |
| **Features** | Bold, italic, underline, fonts, colors, alignment, image attachments |
| **Platforms** | iOS, macOS, tvOS, watchOS |
| **WARNING** | Author stated: "will most likely not be updated... after WWDC 25 announcements" |
| **Verdict** | **NOT recommended** — being deprecated in favor of native SwiftUI |

Source: [RichTextKit GitHub](https://github.com/danielsaidi/RichTextKit)

### Option C: MarkupEditor (Steven Harris)

| Aspect | Details |
|--------|---------|
| **Stars** | 454 |
| **Features** | Bold, italic, underline, strikethrough, headings, tables, lists, images, links |
| **Platforms** | iOS 17+, macOS 14+ |
| **How it works** | Uses WKWebView + ProseMirror (HTML-based) |
| **Pros** | Full-featured, tables + lists, actively maintained |
| **Cons** | WebView-based (not native SwiftUI), heavier footprint |
| **Verdict** | **Good fallback** if native TextEditor doesn't cover tables/checklists |

Source: [MarkupEditor GitHub](https://github.com/stevengharris/MarkupEditor)

### Option D: Canopas Rich Editor SwiftUI

| Aspect | Details |
|--------|---------|
| **Stars** | 262 |
| **Last update** | January 2025 |
| **Features** | Bold, italic, underline, strikethrough, headings, alignment, font customization, export (txt/rtf/pdf/json) |
| **Platforms** | iOS, macOS, tvOS, watchOS, visionOS |
| **Pros** | Multi-platform, MVVM architecture, export support |
| **Cons** | Smaller community, fewer features than MarkupEditor |
| **Verdict** | Decent option but native iOS 26 is better |

Source: [Canopas Rich Editor GitHub](https://github.com/canopas/rich-editor-swiftui)

### DECISION (Confirmed 2026-03-26)

**Use MarkupEditor for the task detail page.** While iOS 26 TextEditor + AttributedString handles basic text formatting (bold/italic/underline/strikethrough), it does NOT support tables, checklists, embedded images, or headings natively. MarkupEditor (WKWebView + ProseMirror) provides the full Notion-like editing experience we need — tables, lists, headings, images, links — all built-in.

| What | Tool |
|------|------|
| Text editing (detail page) | **MarkupEditor** (third-party, 454 stars, actively maintained) |
| Drawing/handwriting (markup mode) | **PencilKit** (Apple native, zero dependencies) |

Source: [MarkupEditor GitHub](https://github.com/stevengharris/MarkupEditor)

---

## 2. Design System: Liquid Glass + SF Symbols

### Liquid Glass (iOS 26)

| Aspect | Details |
|--------|---------|
| **What** | Apple's new design language — translucent, dynamic material with real-time light bending |
| **Introduced** | WWDC 2025 (iOS 26) |
| **Key modifier** | `.glassEffect()` — applies glass material to any view |
| **Glass types** | `.regular` (default), `.clear` (high transparency), `.identity` (no effect) |
| **Shapes** | `.capsule`, `.circle`, `RoundedRectangle`, custom shapes |
| **Automatic** | NavigationBar, TabBar, Toolbar, Sheets, Popovers, Menus all get Liquid Glass automatically when compiled with Xcode 26 |
| **Best practice** | Glass for navigation/controls layer, solid for content layer |
| **Accessibility** | Auto-adapts for reduced transparency/motion settings |

Sources:
- [Liquid Glass Reference (GitHub)](https://github.com/conorluddy/LiquidGlassReference)
- [WWDC25: Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/)
- [Apple Newsroom: New software design](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/)
- [Liquid Glass Kit](https://liquidglass-kit.dev/)

### SF Symbols 7

| Aspect | Details |
|--------|---------|
| **Version** | SF Symbols 7 (latest, WWDC 2025) |
| **Total icons** | 6,900+ symbols |
| **Weights** | 9 weights, 3 scales |
| **New in v7** | Draw animations, variable rendering, enhanced Magic Replace, gradients |
| **Usage** | `Image(systemName: "checkmark.circle")` in SwiftUI |
| **Our use** | ALL icons in the app — tasks, checkmarks, folders, gear, share, formatting, etc. |

Sources:
- [SF Symbols - Apple Developer](https://developer.apple.com/sf-symbols/)
- [What's new in SF Symbols 7 (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/337/)

### RECOMMENDATION

**Use Liquid Glass + SF Symbols 7.** This is exactly the "cool but not too aesthetic" modern look we want. Glass effects come for free on navigation elements. SF Symbols give us 6,900+ native icons — no custom icons needed.

---

## 3. Data Storage & iCloud Sync

### SwiftData + CloudKit (RECOMMENDED)

| Aspect | Details |
|--------|---------|
| **What** | Apple's modern data persistence framework with built-in iCloud sync |
| **Setup** | Add iCloud capability + CloudKit container + Background Modes (Remote Notifications) |
| **Code needed** | Almost zero — SwiftData handles sync automatically |
| **No login** | Uses the device's existing Apple ID — no accounts, no sign-up |
| **Constraints** | Cannot use `@Attribute(.unique)`, all properties need defaults or be optional, relationships must be optional |
| **Multi-device** | Syncs across iPhone, iPad, Mac, Apple Watch automatically |

Sources:
- [Apple Docs: Syncing model data across devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- [HackingWithSwift: Syncing SwiftData with CloudKit](https://www.hackingwithswift.com/books/ios-swiftui/syncing-swiftdata-with-cloudkit)
- [HackingWithSwift: How to sync SwiftData with iCloud](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-sync-swiftdata-with-icloud)

### Important Caveats

| Issue | Solution |
|-------|----------|
| Schema mismatch | Call `initializeCloudKitSchema()` to force CloudKit to match local model |
| Testing | Must test on real device, not simulator |
| Account switching | Local data clears when iCloud account changes — expected behavior |
| Unique attributes | Use UUID as identifier instead of `.unique` |

### RECOMMENDATION

**SwiftData + CloudKit.** Native, zero-account, automatic sync. Exactly what we need — "just works" with the user's Apple ID.

---

## 4. Date Detection & Calendar Sync

### NSDataDetector (Built-in)

| Aspect | Details |
|--------|---------|
| **What** | Apple's built-in NLP text scanner — detects dates, links, phone numbers, addresses |
| **Date formats** | "March 30", "next Friday", "tomorrow", relative dates, timestamps |
| **Dependencies** | None — built into Foundation framework |
| **How** | Create detector with `.date` type, enumerate matches in text, get date ranges |

Source: [NSDataDetector - Apple Docs](https://developer.apple.com/documentation/foundation/nsdatadetector)

### Text Highlighting (AttributedString)

| Aspect | Details |
|--------|---------|
| **How** | Use NSDataDetector to find date ranges → apply blue color attribute to those ranges in AttributedString |
| **iOS 26** | Native TextEditor + AttributedString makes this straightforward |
| **Real-time** | Can detect patterns as user types using iOS 26's TextEditor |

Source: [Real-Time Pattern Detector with iOS 26 TextEditor](https://dimillian.medium.com/building-a-real-time-pattern-detector-with-ios-26s-texteditor-and-attributedstring-07c0f7b88e32)

### EventKit (Calendar Sync)

| Aspect | Details |
|--------|---------|
| **What** | Apple's framework for creating/reading calendar events |
| **Permission** | Must add `NSCalendarsFullAccessUsageDescription` to Info.plist |
| **Access** | Use `EKEventStore.requestFullAccessToEvents()` (iOS 17+) |
| **Creating events** | Set title, start/end date on `EKEvent`, save to `EKEventStore` |
| **Silent** | Can create events programmatically without showing UI to user |

Sources:
- [EventKit - Apple Docs](https://developer.apple.com/documentation/eventkit)
- [Creating and saving calendar events](https://www.createwithswift.com/creating-and-saving-calendar-events/)

### RECOMMENDATION

**NSDataDetector + AttributedString + EventKit.** All native Apple frameworks, zero dependencies. Detect dates as user types → highlight blue → silently sync to Apple Calendar.

---

## 5. Widgets (WidgetKit)

| Aspect | Details |
|--------|---------|
| **Framework** | WidgetKit (native Apple) |
| **Widget types** | Static, interactive (tap actions), Live Activities, Lock Screen, StandBy |
| **Interactive** | Can mark tasks complete directly from widget (iOS 17+, AppIntents) |
| **Customization** | Support dark/light mode, tinted mode, user-configurable settings |
| **Theme-able** | Yes — colors, layouts adapt to system appearance |
| **Size limit** | Widget extension should be under 30MB |
| **2026 trend** | "Surface-centric" — users want to complete tasks from home screen |

Sources:
- [Apple Docs: Building Widgets](https://developer.apple.com/documentation/widgetkit/building_widgets_using_widgetkit_and_swiftui)
- [WidgetExamples GitHub (1.1k stars)](https://github.com/pawello2222/WidgetExamples)
- [iOS Widget Interactivity in 2026](https://dev.to/devin-rosario/ios-widget-interactivity-in-2026-designing-for-the-post-app-era-i17)

### RECOMMENDATION

**WidgetKit with interactive AppIntents.** Users can mark tasks done right from the home screen — huge for a productivity app. This is a v2 feature but architecturally, design the data model to support it from day 1.

---

## 6. Apple Watch

| Aspect | Details |
|--------|---------|
| **Framework** | SwiftUI on watchOS |
| **Data sync** | SwiftData + CloudKit syncs automatically to Watch |
| **Text input** | TextFieldLink (watchOS 9+) for text entry |
| **Task completion** | Simple toggle/checkbox UI |
| **Priority** | Stepper control for sequential values |

Sources:
- [Apple Docs: Creating a watchOS app](https://developer.apple.com/tutorials/swiftui/creating-a-watchos-app)
- [WWDC22: Build a productivity app for Apple Watch](https://developer.apple.com/videos/play/wwdc2022/10133/)

### RECOMMENDATION

**watchOS app using shared SwiftData model.** Same data, same sync, minimal Watch UI — view tasks, mark complete, set priority. v2 feature.

---

## 7. Dark/Light Mode

| Aspect | Details |
|--------|---------|
| **Approach** | Follow system appearance — no manual toggle needed |
| **How** | SwiftUI automatically handles this via semantic colors and `@Environment(\.colorScheme)` |
| **Best practice** | Use `Color.primary`, `Color.secondary`, `.background` — they adapt automatically |
| **Liquid Glass** | Automatically adapts transparency/luminance to dark vs light mode |
| **Custom colors** | Define in Asset Catalog with "Any/Dark" variants |

### RECOMMENDATION

**Use semantic colors + Asset Catalog dark variants.** System handles everything. Liquid Glass adapts automatically. Zero code for basic dark/light support.

---

## 7b. Drawing & Handwriting Tools: PencilKit (Apple Native)

| Aspect | Details |
|--------|---------|
| **Framework** | PencilKit — `import PencilKit` |
| **Type** | Apple native — zero dependencies |
| **SwiftUI** | Wrap via `UIViewRepresentable` (standard, well-documented pattern) |
| **Same as Apple Notes?** | Yes — `PKToolPicker` is the exact same floating toolbar Apple Notes uses |

### Tools Included for Free

| Tool | Included? | Notes |
|------|-----------|-------|
| Pen | Yes | Multiple tip styles |
| Pencil | Yes | Tilt sensitivity, pressure |
| Marker/Crayon | Yes | Thick strokes |
| Highlighter | Partial | Marker with reduced opacity |
| Eraser (pixel) | Yes | Erases specific areas |
| Eraser (vector) | Yes | Removes entire strokes |
| Color picker | Yes | Full color wheel |
| Ruler | Yes | Straight line guide |
| Apple Pencil | Yes | Low-latency, palm rejection |
| Finger drawing | Yes | Works without Apple Pencil |

### Key Components

| Component | What It Does |
|-----------|-------------|
| `PKCanvasView` | The drawing canvas |
| `PKToolPicker` | The floating toolbar (pens, erasers, colors) |
| `PKDrawing` | Data model — encode to `Data` for storage in SwiftData |

### Storage & Sync

| Question | Answer |
|----------|--------|
| Save drawings? | `PKDrawing` → encode to `Data` → store in SwiftData |
| iCloud sync? | Yes — as `Data` blob, syncs like any other property |
| Works on iPad + iPhone? | Yes — Apple Pencil on iPad, finger on both |

Sources:
- [PencilKit in SwiftUI](https://swiftprogramming.com/pencilkit-swiftui/)
- [Customizing PencilKit's Tool Picker](https://www.wesleymatlock.com/customizing-pencilkit-going-past-apples-tool-picker/)
- [PencilKit Getting Started (Kodeco)](https://www.kodeco.com/12198216-drawing-with-pencilkit-getting-started)

---

## 7c. Siri Integration: App Intents (Apple Native)

| Aspect | Details |
|--------|---------|
| **Framework** | App Intents — `import AppIntents` |
| **Type** | Apple native — zero dependencies |
| **Minimum iOS** | iOS 16+ (we target iOS 26) |
| **Works on** | iPhone, iPad, Mac, Apple Watch — anywhere Siri works |

### What It Enables

| Voice Command | What Happens |
|--------------|-------------|
| "Hey Siri, create a task in [OurApp]" | Creates new task with voice-captured title |
| "Hey Siri, create a task in [OurApp] with details: buy groceries tomorrow 5pm" | Creates task title + populates detail page body. Date auto-detected |
| "Hey Siri, show my tasks in [OurApp]" | Opens the app to task list |

### What We Build

| Component | What | Framework |
|-----------|------|-----------|
| `AppIntent` struct | Defines "Create Task" action | App Intents (native) |
| `AppShortcutsProvider` | Registers phrases with Siri | App Intents (native) |
| Parameter resolution | Handles title + optional details from voice | App Intents (native) |
| SwiftData write | Saves task to DB (syncs via iCloud) | SwiftData (native) |

### Apple Intelligence Bonus

| Feature | Impact |
|---------|--------|
| Personal context | Siri understands cross-app context ("remind me about that email") |
| On-screen awareness | Siri can act on what's visible |
| Future-proof | App Intents = gateway to all future Apple Intelligence features |

### Siri "Remind Me" — Auto-Import from Apple Reminders (KEY FEATURE)

Users DON'T need to say our app name. Instead, we auto-import from Apple Reminders:

| Step | What Happens |
|------|-------------|
| 1 | User enables "Siri & Reminders" integration in our app settings |
| 2 | Our app requests access to Apple Reminders via EventKit (EKReminder) |
| 3 | User says "Hey Siri, remind me to buy groceries" — natural, no app name |
| 4 | Siri creates reminder in Apple Reminders (normal behavior) |
| 5 | Our app watches for new reminders and auto-imports them as tasks |
| 6 | Task appears in our app within seconds |
| 7 | Optionally auto-delete the Apple Reminder after import |

This is how **Any.do, Things 3, and OmniFocus** do it. Permission: `NSRemindersFullAccessUsageDescription` in Info.plist.

Sources:
- [Any.do + Siri & Apple Reminders](https://support.any.do/en/articles/8634346-any-do-siri-apple-reminders)
- [Things 3: Adding To-Dos via Apple Reminders](https://culturedcode.com/things/support/articles/2803561/)

Sources:
- [Apple Docs: Integrating actions with Siri and Apple Intelligence](https://developer.apple.com/documentation/appintents/integrating-actions-with-siri-and-apple-intelligence)
- [WWDC25: Get to know App Intents](https://developer.apple.com/videos/play/wwdc2025/244/)
- [WWDC24: Bring your app to Siri](https://developer.apple.com/videos/play/wwdc2024/10133/)
- [App Intents SwiftUI tutorial](https://www.createwithswift.com/using-app-intents-swiftui-app/)

---

## Summary: FINAL Recommended Tech Stack

| Component | Tool | Type | Why |
|-----------|------|------|-----|
| **Rich Text Editor** | MarkupEditor | Third-party (454 stars) | Full Notion-like editing: tables, lists, headings, images, links |
| **Drawing/Handwriting** | PencilKit | Apple native | Same engine as Apple Notes — pen, pencil, eraser, color picker |
| **Siri Integration** | App Intents | Apple native | Voice-create tasks from any device |
| **Design Language** | Liquid Glass + SF Symbols 7 | Apple native (iOS 26) | Modern, automatic, 6,900+ icons |
| **Data + Sync** | SwiftData + CloudKit | Apple native | Auto iCloud sync, no login needed |
| **Date Detection** | NSDataDetector | Apple native | Built-in NLP, handles natural language dates |
| **Text Highlighting** | AttributedString | Apple native | Highlight detected dates in blue |
| **Calendar Sync** | EventKit | Apple native | Silent event creation to Apple Calendar |
| **Widgets** | WidgetKit + AppIntents | Apple native | Interactive task completion from home screen |
| **Apple Watch** | SwiftUI + shared SwiftData | Apple native | Auto sync via CloudKit |
| **Icons** | SF Symbols 7 | Apple native | 6,900+ symbols, all styles we need |
| **Theme** | System appearance + Asset Catalog | Apple native | Auto dark/light, Liquid Glass adapts |

### Dependency Count

| Type | Count | What |
|------|-------|------|
| **Third-party** | 1 | MarkupEditor |
| **Apple native** | 10 | Everything else |
| **Total dependencies to manage** | 1 | Minimal maintenance burden |

This is as lean as it gets — 1 external dependency for the full editing experience, everything else is Apple's own frameworks.

---

## 8. SF Symbols Icon Map (What We'll Use)

Every icon in our app comes from SF Symbols 7. No custom icons, no emojis.

| App Feature | SF Symbol Name | Preview |
|---|---|---|
| Task checkbox (empty) | `circle` | Empty circle |
| Task checkbox (done) | `checkmark.circle.fill` | Filled checkmark |
| Add new task (+) | `plus` or `plus.circle.fill` | Plus button |
| Settings gear | `gearshape` | Gear icon |
| Share | `square.and.arrow.up` | Standard iOS share |
| Back arrow | `chevron.left` | Back navigation |
| Folders | `folder` / `folder.fill` | Folder icon |
| Attachment | `paperclip` | Paperclip |
| Bold | `bold` | B formatting |
| Italic | `italic` | I formatting |
| Underline | `underline` | U formatting |
| Strikethrough | `strikethrough` | S formatting |
| Text format menu | `textformat` | Aa menu |
| Checklist | `checklist` | Checklist toggle |
| Table | `tablecells` | Grid table |
| Markup/drawing | `pencil.tip.crop.circle` | Drawing tools |
| Highlighter | `highlighter` | Highlighter |
| Eraser | `eraser` | Eraser |
| Color picker | `paintpalette` | Color selection |
| Delete/trash | `trash` | Delete action |
| Sort | `arrow.up.arrow.down` | Sort options |
| Calendar/date | `calendar` | Date features |
| Priority flag | `flag.fill` | Priority marker |
| Indent | `increase.indent` | Indent text |
| Outdent | `decrease.indent` | Outdent text |
| Bullet list | `list.bullet` | Bulleted list |
| Search (v2) | `magnifyingglass` | Search bar |

Download the free **SF Symbols 7 Mac app** to browse all 6,900+ icons: https://developer.apple.com/sf-symbols/

---

## 9. Color System (Priority Markers + Semantic Colors)

### Priority Colors (Custom — 3 only)

| Priority | Color | Asset Catalog Name | Usage |
|----------|-------|-------------------|-------|
| **Urgent** | Red | `PriorityHigh` | High priority tasks |
| **Medium** | Orange| `PriorityMedium` | Medium priority tasks |
| **Default** | Gray | `PriorityDefault` | No priority set (new tasks) |

Each defined in Asset Catalog with light AND dark mode variants.

### System Semantic Colors (Built-in — no code needed)

| Role | SwiftUI Color | Where Used |
|------|--------------|------------|
| Task title text | `Color.primary` | Main text (auto black/white) |
| Timestamps, subtitles | `Color.secondary` | Creation date, metadata |
| Placeholder/hints | `Color(.tertiaryLabel)` | "Add Note" placeholder |
| Main background | `Color(.systemBackground)` | Screen background |
| Detected dates | `Color.accentColor` (blue) | Highlighted dates in text |
| Dividers | `Color(.separator)` | Lines between tasks |

### NEVER hardcode these

| Bad | Good |
|-----|------|
| `Color.white` for backgrounds | `Color(.systemBackground)` |
| `Color.black` for text | `Color.primary` |
| `Color.gray` for subtitles | `Color.secondary` |

---

## 10. SwiftData iCloud Sync — Setup Checklist

| Step | What To Do |
|------|-----------|
| 1 | Add **iCloud capability** in Xcode project settings |
| 2 | Select **CloudKit** and add a container (e.g., `iCloud.com.yourapp.tasks`) |
| 3 | Add **Background Modes** capability → check "Remote Notifications" |
| 4 | Set `cloudKitDatabase: .automatic` in `ModelConfiguration` |
| 5 | Make all `@Model` properties optional or have default values |
| 6 | Make all relationships optional |
| 7 | Do NOT use `@Attribute(.unique)` — use UUID instead |
| 8 | Test on **real device** (simulator iCloud sync is unreliable) |
| 9 | Call `initializeCloudKitSchema()` if sync schema is out of date |

### Key Behaviors

| Behavior | Details |
|----------|---------|
| Sync speed | Eventual consistency — typically seconds to minutes |
| No login needed | Uses device's signed-in Apple ID automatically |
| Account switch | Local data clears and reloads from new account — expected behavior |
| Offline | Works offline, syncs when back online |
| Multi-device | iPhone, iPad, Mac, Apple Watch — all automatic |

---

## 11. Layout & Design Rules (Apple HIG)

Reference: [Apple Human Interface Guidelines — Layout](https://developer.apple.com/design/human-interface-guidelines/layout)

### Spacing & Padding

| Rule | Value | Where It Applies |
|------|-------|-----------------|
| Screen edge margins | 16-20pt | Space between content and screen edges |
| Between list items | 8pt | Space between tasks in the task list |
| Between cards | 16-24pt | Space between task cards (24pt if content-heavy) |
| Internal card padding | 12-16pt | Space inside a task card |
| Default SwiftUI `.padding()` | 16pt all edges | Apple's default — use this as baseline |
| Section spacing | 20-32pt | Space between sections (e.g., above "Folders" header) |

### Touch Targets

| Rule | Value | Why |
|------|-------|-----|
| Minimum tap area | **44x44 points** | Apple's hard rule — anything smaller = missed taps, frustrated users |
| Color marker square | At least 44x44pt tap area | Even if visually smaller, the touchable area must be 44pt |
| "+" button | At least 44x44pt | Apple standard |
| Three dots "..." | At least 44x44pt | Must be easy to tap |
| Swipe gesture area | Full row width | Swipe actions use the entire task row |

### Typography (SF Pro — System Font)

| Element | Size | Weight | Line Height |
|---------|------|--------|-------------|
| Task title text | 17pt | Regular | 1.5x (25.5pt) |
| Task body preview | 15pt | Regular | 1.5x (22.5pt) |
| Timestamps/subtitles | 13pt | Regular | 1.5x (19.5pt) |
| Section headers (e.g., "Folders") | 20-22pt | Bold | 1.3x |
| Navigation title | 34pt | Bold | 1.2x (Large Title style) |
| Minimum readable text | 11pt | — | Never go smaller |
| Letter spacing | Default (0) | — | SF Pro is optimized, don't adjust |

### Safe Areas

| Concept | What It Means |
|---------|---------------|
| Safe area | Region not hidden by notch, Dynamic Island, or home indicator |
| SwiftUI default | Content stays inside safe bounds automatically |
| `.ignoresSafeArea()` | Only use for backgrounds extending edge-to-edge |
| `.safeAreaInset()` | Add custom toolbars/buttons while keeping content visible |
| `.safeAreaPadding()` | Inset scrollable content (not the scroll view itself) |

### Visual Hierarchy

| Principle | How We Apply It |
|-----------|----------------|
| Size = importance | Task title (17pt) > subtitle (13pt) > metadata |
| Weight = emphasis | Bold for headers, Regular for body |
| Color = attention | Red marker = urgent, blue = detected dates, gray = secondary |
| Spacing = grouping | Related items close together, sections separated by 20-32pt |
| Whitespace = breathing room | Generous padding prevents cramped feeling |

### Key Design Numbers for Our App

| Element | Specification |
|---------|--------------|
| Task card height | ~60-72pt (title + subtitle + padding) |
| Color marker square | 12-16pt visually, 44pt tap area |
| Bottom "+" button | 56pt diameter (common iOS FAB size), 44pt minimum |
| Toolbar height | 44pt (Apple standard) |
| Navigation bar | 44pt (standard) or 96pt (large title) |
| Keyboard toolbar | 44pt height |
| Between-task divider | 0.5pt line with `Color(.separator)` |

Sources:
- [Apple HIG: Layout](https://developer.apple.com/design/human-interface-guidelines/layout)
- [Apple HIG: Typography](https://developer.apple.com/design/human-interface-guidelines/typography)
- [iOS Design Guidelines (Visual Cheat Sheet)](https://ivomynttinen.com/blog/ios-design-guidelines/)
- [Design+Code: iOS Design Do's and Don'ts](https://designcode.io/ios-design-handbook-dos-and-donts/)

---

## 12. Next Steps Before Coding

| Step | What | Why |
|------|------|-----|
| 1 | Download **SF Symbols 7** Mac app | Browse icons, pick exact ones for each button |
| 2 | Watch **WWDC25 session 280** (Rich text with AttributedString) | Understand native text editor capabilities |
| 3 | Watch **WWDC25 session 323** (Build SwiftUI app with Liquid Glass) | Understand the new design system |
| 4 | Watch **WWDC25 session 337** (SF Symbols 7) | Understand new icon animations |
| 5 | Generate the **PRD** (`/prd`) | Formalize everything into a structured product document |
| 6 | Define the **data model** (Task, Folder) | Plan SwiftData @Model schemas |
| 7 | Build v1 skeleton | Task list + detail + priority colors |
