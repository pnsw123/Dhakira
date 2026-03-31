# Pre-Launch Requirements — V1 (iPhone + iPad)
> Last updated: March 30, 2026
> Status: **95% Complete** — 2–3 days to launch
> Testing first. Themes second. Branding and publishing last.

---

## Overall Progress

| Area | Status | Notes |
|---|---|---|
| Core Note Features | ✅ Done | Editor, formatting, folders all working |
| Calendar Integration | ✅ Done | Events save at correct time, 5pm → 5pm in Apple Calendar |
| Widget System | ✅ Done | Fully compatible, theme syncs almost instantly |
| Theme System | ✅ Done | Applies across app and widgets live |
| Export | ✅ Done | PDF, RTF, plain text |
| Attachments | ✅ Done | Photos, files, voice, scan |
| Reminders Import | ✅ Done | |
| More Themes (paid) | 🔲 Remaining | Need to add more theme designs |
| Paywall | 🔲 Remaining | StoreKit integration |
| Testing + Edge Cases | 🔲 Remaining | Ongoing until launch |
| Branding + Logo | 🔲 Remaining | App icon, screens |
| App Store Submission | 🔲 Remaining | License, listing, review |
| Domain | 🔲 Remaining | Find and register |

---

## Priority 1 — Testing (Do This Repeatedly Until Launch)
Test everything below. If anything breaks, fix it before moving on.

### Core Note Features
- [x] Create a new task / note
- [x] Type in the editor — text appears correctly
- [x] Bold, italic, underline, strikethrough formatting works
- [x] Heading 1, 2, 3 apply and revert correctly
- [x] Bullet list inserts and toggles off
- [x] Quote block inserts with blue bar and toggles off
- [x] Checklist inserts and checkbox toggles checked/unchecked
- [x] Slash `/` menu appears, filters, and applies command correctly
- [x] Slash menu dismisses on backspace
- [x] Drag-to-reorder toolbar icons works

### Folders & Navigation
- [x] Create a new folder
- [x] Rename a folder inline
- [x] Delete a folder
- [x] Navigate Tasks → Folders → Tasks smoothly
- [x] Select a task list from a folder and it becomes active

### Calendar & Date Detection
- [x] Type a date in a note title (e.g. "Dentist tomorrow at 3pm")
- [x] App detects the date automatically
- [x] Calendar event is created in Apple Calendar
- [x] Event has correct title, date, and time ✅ confirmed 5pm → 5pm
- [x] Event has 15-minute reminder alarm
- [ ] Edit the date in the title — event updates (re-test)
- [ ] Remove the date from the title — event is deleted (re-test)
- [ ] Deep link in calendar event opens the app at the correct note (re-test)

### Export
- [x] PDF export: tap export → share sheet appears with .pdf file
- [x] PDF file opens correctly and contains title + body content
- [x] Word/RTF export: share sheet appears with .rtf file
- [x] RTF file opens in Pages or Word correctly
- [x] Plain text share works

### Attachments
- [x] Attach a photo from photo library
- [x] Attach a file (PDF, doc, etc.)
- [x] Record and attach a voice message
- [x] Scan a document with camera (text scan)
- [x] Attached items appear inline in the note

### Reminders Import
- [x] Grant Reminders permission
- [x] Import from Apple Reminders works
- [x] Imported reminder becomes a task with correct title and notes

### Sync & Data
- [x] Close and reopen app — all notes are still there
- [x] Recently Completed shows completed tasks
- [x] Recently Deleted shows soft-deleted tasks
- [x] Restore a deleted task works
- [x] Permanently delete a task works

### Deep Links & Siri
- [ ] Siri shortcut "Create Task" works (re-test)
- [ ] Deep link URL (prodnote://task/{uuid}) opens correct note (re-test)

### iPhone Polish
- [ ] App looks correct in Light Mode (re-test all themes)
- [ ] App looks correct in Dark Mode (re-test all themes)
- [ ] No visible layout breaks on iPhone 16 Pro Max
- [ ] No visible layout breaks on iPhone SE (small screen)
- [ ] App does not crash on cold launch

### iPad Polish
- [ ] No visible layout breaks on iPad Pro 13"
- [ ] No visible layout breaks on iPad Mini
- [ ] App works correctly in iPad Split View
- [ ] App works correctly in Slide Over
- [ ] Keyboard shortcuts work on iPad with external keyboard
- [ ] App does not crash on cold launch on iPad

### Edge Cases to Think Through
- [ ] What happens if you delete a note that has a calendar event?
- [ ] What if the user denies calendar permission — does the app crash or handle it gracefully?
- [ ] What if a note title has two dates in it?
- [ ] What happens when storage is almost full?
- [ ] What if the user types a date with no time — does it default reasonably?
- [ ] What if the widget loads with no notes yet?
- [ ] What if the user switches themes rapidly — does anything break?
- [ ] What if a photo attachment is very large?
- [ ] What if the user force-quits mid-edit — is anything lost?
- [ ] Accessibility (VoiceOver) — does the app work for visually impaired users?

---

## Priority 2 — More Themes (Revenue Driver)
The infrastructure is done. Now add more theme designs.

### Current Theme Status
| Name | Tier | Status |
|---|---|---|
| Default | Free | ✅ Done |
| Midnight | Free | ✅ Done |
| Academia | Paid | 🔲 Design + build |
| Nord | Paid | 🔲 Design + build |
| Tokyo Night | Paid | 🔲 Design + build |
| Forest | Paid | 🔲 Design + build |
| Rosé | Paid | 🔲 Design + build |
| Void | Paid (bundle) | 🔲 Design + build |

### Theme Checklist (per theme)
- [ ] Colors defined (background, text, accent)
- [ ] Tested on iPhone (light + dark)
- [ ] Tested on iPad
- [ ] Widget inherits theme correctly
- [ ] Theme persists after app kill/reopen

---

## Priority 3 — Widgets ✅ (Infrastructure Complete)
Widget system is fully working and syncs with themes instantly.

### Remaining Widget Polish
- [ ] All widgets tested on iPhone home screen
- [ ] All widgets tested on iPad home screen
- [ ] Lock screen widgets look correct
- [ ] Tinted mode (iOS 18) looks correct
- [ ] No stale data after theme change

---

## Priority 4 — Paywall
- [ ] Free tier confirmed: Default + Midnight only
- [ ] Paid theme pack pricing locked ($1.99/pack or $7.99 bundle)
- [ ] StoreKit 2 `Product.products` integrated
- [ ] `product.purchase()` flow works end-to-end
- [ ] `Transaction.updates` listener active (restores purchases)
- [ ] `ProductView` / `StoreView` UI in theme picker
- [ ] Purchases persist after app reinstall (restore purchases button)
- [ ] Tested in Xcode sandbox (StoreKit testing)

---

## Priority 5 — Apple Developer Program + iCloud
- [x] Enrolled at developer.apple.com/programs/enroll ($99/year)
- [ ] iCloud + CloudKit capability added in Xcode
- [ ] iCloud sync tested: notes appear on second device
- [ ] App Group `group.com.prodnote.shared` confirmed working

---

## Priority 6 — Branding
- [ ] App name finalized (confirm "ProdNote" or other)
- [ ] Logo designed (1024x1024 px, works on white and black backgrounds)
- [ ] All Xcode icon sizes added to Assets catalog
- [ ] App Store screenshots planned and captured (see below)
- [ ] Domain registered (e.g. prodnote.app or similar)

---

## Priority 7 — App Store Screenshots
Showcase themes and widgets. Capture on real device or high-quality simulator.

| Screen | Status |
|---|---|
| Home / Folders screen | 🔲 |
| Task list view | 🔲 |
| Note editor with formatting toolbar | 🔲 |
| Slash `/` command menu open | 🔲 |
| Theme picker showing paid options | 🔲 |
| Widget on home screen with active theme | 🔲 |
| Calendar event created from a note | 🔲 |

- [ ] Minimum 3 screenshots — iPhone 6.9"
- [ ] Minimum 3 screenshots — iPhone 6.5"
- [ ] Minimum 3 screenshots — iPad Pro 13"

---

## Priority 8 — Final Submission
- [ ] App Store description written (highlight themes + widgets + calendar)
- [ ] Keywords researched and added
- [ ] Bundle ID set correctly in Xcode
- [ ] Version 1.0.0, Build 1
- [ ] Archive build (Product → Archive)
- [ ] Upload via Xcode Organizer
- [ ] App Store Connect listing complete
- [ ] Submit for Apple Review

---

## Tech Reference — Theme System APIs

> Exact iOS 26 SwiftUI APIs, docs, and WWDC sessions. Use this while coding.

### Deployment Target
| Target | What You Get |
|---|---|
| iOS 17 minimum | All base grid, scroll, StoreKit APIs |
| iOS 18 | MeshGradient, zoom transition |
| iOS 26 | Liquid Glass, glassEffect, GlassEffectContainer, ConcentricRectangle |
| Strategy | Build on iOS 17. Gate glass behind `if #available(iOS 26, *)` |

### Screen 1 — Theme Gallery
| API | Exact Syntax | iOS | Docs |
|---|---|---|---|
| LazyVGrid | `LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) { }` | 14 | https://developer.apple.com/documentation/swiftui/lazyvgrid |
| searchable | `.searchable(text: $q, placement: .navigationBarDrawer, prompt: "Search themes")` | 15 | https://developer.apple.com/documentation/swiftui/view/searchable(text:placement:prompt:)-18a8f |
| ultraThinMaterial | `.background(.ultraThinMaterial)` | 15 | https://developer.apple.com/documentation/swiftui/material |
| contentMargins | `.contentMargins(16, for: .scrollContent)` | 17 | https://developer.apple.com/documentation/swiftui/view/contentmargins(_:for:) |
| containerRelativeFrame | `.containerRelativeFrame(.horizontal, count: 2, spacing: 12)` | 17 | https://developer.apple.com/documentation/swiftui/view/containerrelativeframe(_:count:span:spacing:alignment:) |
| scrollTransition | `.scrollTransition { c, p in c.opacity(p.isIdentity ? 1:0).scaleEffect(p.isIdentity ? 1:0.85) }` | 17 | https://developer.apple.com/documentation/swiftui/view/scrolltransition(_:axis:transition:) |
| MeshGradient | `MeshGradient(width: 3, height: 3, points: [...], colors: [...])` inside `TimelineView(.animation)` | 18 | https://developer.apple.com/documentation/swiftui/meshgradient |
| matchedTransitionSource | `.matchedTransitionSource(id: theme.id, in: namespace)` | 18 | https://developer.apple.com/documentation/swiftui/view/matchedtransitionsource(id:in:) |
| ConcentricRectangle | `.clipShape(ConcentricRectangle())` | 26 | https://developer.apple.com/documentation/swiftui/concentricrectangle |
| scrollEdgeEffectStyle | `.scrollEdgeEffectStyle(.soft, for: .all)` | 26 | https://developer.apple.com/documentation/SwiftUI/View/scrollEdgeEffectStyle(_:for:) |
| symbolEffect drawOn | `.symbolEffect(.drawOn, value: isSelected)` | 26 | https://developer.apple.com/documentation/swiftui/view/symboleffect(_:options:value:) |

### Screen 2 — Theme Detail / Customization
| API | Exact Syntax | iOS | Docs |
|---|---|---|---|
| navigationTransition zoom | `.navigationTransition(.zoom(sourceID: id, in: ns))` on destination | 18 | https://developer.apple.com/documentation/SwiftUI/NavigationTransition/zoom(sourceID:in:) |
| glassEffect regular | `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))` | 26 | https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:) |
| glassEffect interactive | `.glassEffect(.regular.interactive(), in: .capsule)` | 26 | https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:) |
| GlassEffectContainer | `GlassEffectContainer(spacing: 8) { }` | 26 | https://developer.apple.com/documentation/swiftui/glasseffectcontainer |
| buttonStyle glass | `.buttonStyle(.glass)` — secondary | 26 | https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views |
| buttonStyle glassProminent | `.buttonStyle(.glassProminent)` — primary Apply button | 26 | https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views |
| backgroundExtensionEffect | `.backgroundExtensionEffect()` — background bleeds into safe areas | 26 | https://developer.apple.com/documentation/SwiftUI/View/backgroundExtensionEffect() |
| Phone mockup scaling | `.scaleEffect(0.35).frame(width:180, height:370).clipped()` + `allowsHitTesting(false)` | 14 | N/A |

### Screen 3 — Scope Selector (All / App / Widgets pill)
| API | Exact Syntax | iOS | Docs |
|---|---|---|---|
| matchedGeometryEffect pill | `.matchedGeometryEffect(id: "pill", in: namespace)` on `Capsule()` fill | 14 | https://developer.apple.com/documentation/swiftui/view/matchedgeometryeffect(id:in:properties:anchor:issource:) |
| spring animation | `.animation(.spring(duration: 0.3, bounce: 0.25), value: selected)` | 17 | https://developer.apple.com/documentation/SwiftUI/Animation/spring(duration:bounce:blendDuration:) |

### Screen 4 — Bottom Bar (Color / Gradient / Photo / Blur)
| API | Exact Syntax | iOS | Docs |
|---|---|---|---|
| PhotosPicker | `PhotosPicker("Photo", selection: $item, matching: .images)` | 16 | https://developer.apple.com/documentation/photosui/photospicker |
| loadTransferable | `try? await item?.loadTransferable(type: Data.self)` | 16 | https://developer.apple.com/documentation/photokit/bringing-photos-picker-to-your-swiftui-app |
| ColorPicker | `ColorPicker("", selection: $color, supportsOpacity: false)` | 14 | https://developer.apple.com/documentation/swiftui/colorpicker |
| blur | `.blur(radius: 12)` | 13 | https://developer.apple.com/documentation/swiftui/view/blur(radius:opaque:) |

### Screen 5 — Widget Preview Mockup
| Widget size | Frame to use | Corner radius |
|---|---|---|
| systemSmall | `.frame(width: 155, height: 155)` | 22pt |
| systemMedium | `.frame(width: 329, height: 155)` | 22pt |
| systemLarge | `.frame(width: 329, height: 345)` | 22pt |
| Note | `WidgetPreviewContext` is Xcode-only — use scaled SwiftUI views in main app | — |

### Screen 6 — StoreKit Paywall
| API | Exact Syntax | iOS | Docs |
|---|---|---|---|
| Product.products | `try await Product.products(for: ["com.prodnote.theme.x"])` | 15 | https://developer.apple.com/documentation/storekit/storekit-views |
| product.purchase | `let result = try await product.purchase()` | 15 | https://developer.apple.com/storekit/ |
| Transaction.updates | `for await update in Transaction.updates { }` | 15 | https://developer.apple.com/storekit/ |
| ProductView | `ProductView(id: "com.prodnote.theme.x")` | 17 | https://developer.apple.com/documentation/storekit/productview |
| StoreView | `StoreView(ids: ["id1", "id2"])` | 17 | https://developer.apple.com/documentation/storekit/storeview |
| WWDC | Meet StoreKit for SwiftUI — WWDC23 #10013 | — | https://developer.apple.com/videos/play/wwdc2023/10013/ |

### Widget Tinting (Widget Extension target)
| API | Exact Syntax | iOS | Docs |
|---|---|---|---|
| widgetAccentable | `.widgetAccentable()` | 16 | https://developer.apple.com/documentation/swiftui/view/widgetaccentable(_:) |
| widgetAccentedRenderingMode | `Image("x").widgetAccentedRenderingMode(.accentedDesaturated)` | 18 | https://developer.apple.com/documentation/swiftui/image/widgetaccentedrenderingmode(_:) |
| widgetRenderingMode | `@Environment(\.widgetRenderingMode) var mode` | 16 | https://developer.apple.com/documentation/swiftui/environmentvalues/widgetrenderingmode |
| showsWidgetContainerBackground | `@Environment(\.showsWidgetContainerBackground) var showsBg` | 17 | https://developer.apple.com/documentation/swiftui/environmentvalues/showswidgetcontainerbackground |
| containerBackground | `.containerBackground(for: .widget) { MeshGradient(...) }` | 17 | https://developer.apple.com/documentation/widgetkit |

### Background Image Rules
| Rule | Detail |
|---|---|
| Always downsample | 12MP photo = 87MB raw → must downsample to ~11MB using `CGImageSourceCreateThumbnailAtIndex` |
| Display pattern | `.resizable().scaledToFill().ignoresSafeArea(.all)` — always this combination |
| Readability overlay | `Color.black.opacity(0.25)` light / `Color.black.opacity(0.55)` dark |
| Storage | Documents directory as JPEG 0.85 quality. Path saved in `@AppStorage` |
| App Group | `group.com.prodnote.shared` — widget reads image from same container |
| WWDC reference | WWDC 2018 Session 416 — Image and Graphics Best Practices |

### Theme Names (V1)
| Name | Tier | Audience | Color Direction | Status |
|---|---|---|---|---|
| Default | Free | Everyone | Warm off-white (current look) | ✅ Done |
| Midnight | Free | Everyone | Deep charcoal (current dark) | ✅ Done |
| Academia | Paid | Millennial women, students | Warm sepia, cream, deep brown | 🔲 |
| Nord | Paid | Men, professionals | Arctic blue-grey, icy white | 🔲 |
| Tokyo Night | Paid | Gen Z, creatives | Deep navy, neon purple, electric teal | 🔲 |
| Forest | Paid | Creatives, nature lovers | Muted green, earthy brown, amber | 🔲 |
| Rosé | Paid | Women 20–35 | Dusty rose, warm pink, cream | 🔲 |
| Void | Paid (bundle) | Power users, OLED screens | Pure #000000 black | 🔲 |

### Key WWDC Sessions
| Session | Year | What It Covers |
|---|---|---|
| WWDC25 #323 — Build SwiftUI app with new design | 2025 | Liquid Glass full reference |
| WWDC24 #10145 — Enhance UI animations and transitions | 2024 | zoom transition, matchedTransitionSource |
| WWDC23 #10013 — Meet StoreKit for SwiftUI | 2023 | ProductView, StoreView, purchase flow |
| WWDC23 #10027 — Bring Widgets to New Places | 2023 | StandBy, iPad widgets |
| WWDC23 #10028 — Bring Widgets to Life | 2023 | Interactive widgets |
| WWDC22 #10058 — SwiftUI on iPad | 2022 | NavigationSplitView |
| WWDC22 #10050 — Complications and Widgets: Reloaded | 2022 | Lock screen widgets |
| WWDC18 #416 — Image and Graphics Best Practices | 2018 | Image downsampling (MANDATORY read) |
