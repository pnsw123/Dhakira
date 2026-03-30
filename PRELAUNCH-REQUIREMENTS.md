# Pre-Launch Requirements — V1 (iPhone + iPad)
> Testing first. Themes + Widgets second. Branding and publishing last.
> Scope: Full iOS theme control, full widget designs, background support — iPhone and iPad.

---

## Priority 1 — Simulator Testing
Fix everything broken before moving on. Nothing else matters until this passes.

### Core Note Features
- [ ] Create a new task / note
- [ ] Type in the editor — text appears correctly
- [ ] Bold, italic, underline, strikethrough formatting works
- [ ] Heading 1, 2, 3 apply and revert correctly
- [ ] Bullet list inserts and toggles off
- [ ] Quote block inserts with blue bar and toggles off
- [ ] Checklist inserts and checkbox toggles checked/unchecked
- [ ] Slash `/` menu appears, filters, and applies command correctly
- [ ] Slash menu dismisses on backspace
- [ ] Drag-to-reorder toolbar icons works

### Folders & Navigation
- [ ] Create a new folder
- [ ] Rename a folder inline
- [ ] Delete a folder
- [ ] Navigate Tasks → Folders → Tasks smoothly
- [ ] Select a task list from a folder and it becomes active

### Calendar & Date Detection
- [ ] Type a date in a note title (e.g. "Dentist tomorrow at 3pm")
- [ ] App detects the date automatically
- [ ] Calendar event is created in Apple Calendar
- [ ] Event has correct title, date, and time
- [ ] Event has 15-minute reminder alarm
- [ ] Edit the date in the title — event updates
- [ ] Remove the date from the title — event is deleted
- [ ] Deep link in calendar event opens the app at the correct note

### Export
- [ ] PDF export: tap export → share sheet appears with .pdf file
- [ ] PDF file opens correctly and contains title + body content
- [ ] Word/RTF export: share sheet appears with .rtf file
- [ ] RTF file opens in Pages or Word correctly
- [ ] Plain text share works

### Attachments
- [ ] Attach a photo from photo library
- [ ] Attach a file (PDF, doc, etc.)
- [ ] Record and attach a voice message
- [ ] Scan a document with camera (text scan)
- [ ] Attached items appear inline in the note

### Reminders Import
- [ ] Grant Reminders permission
- [ ] Import from Apple Reminders works
- [ ] Imported reminder becomes a task with correct title and notes

### Sync & Data
- [ ] Close and reopen app — all notes are still there
- [ ] Recently Completed shows completed tasks
- [ ] Recently Deleted shows soft-deleted tasks
- [ ] Restore a deleted task works
- [ ] Permanently delete a task works

### Deep Links & Siri
- [ ] Siri shortcut "Create Task" works
- [ ] Deep link URL (prodnote://task/{uuid}) opens correct note

### iPhone Polish
- [ ] App looks correct in Light Mode
- [ ] App looks correct in Dark Mode
- [ ] No visible layout breaks on iPhone 16 Pro Max
- [ ] No visible layout breaks on iPhone SE (small screen)
- [ ] App does not crash on cold launch

### iPad Polish
- [ ] No visible layout breaks on iPad Pro 13"
- [ ] No visible layout breaks on iPad Mini
- [ ] App works correctly in iPad Split View (two apps side by side)
- [ ] App works correctly in Slide Over (floating window)
- [ ] Keyboard shortcuts work on iPad with external keyboard
- [ ] App does not crash on cold launch on iPad

---

## Priority 2 — Theme System (V1 Revenue Driver)
Full iOS theme control. Works identically on iPhone and iPad.

### Bones (Infrastructure — no visible change to users)
- [ ] Create `AppTheme` struct with all color, font, spacing tokens
- [ ] Register AppTheme into SwiftUI environment (`@Entry` / `EnvironmentKey`)
- [ ] Create `ThemeManager` service — saves/loads selected theme via UserDefaults
- [ ] Inject theme at app root in `Note_takingApp.swift`
- [ ] Migrate `Color+App.swift` static vars to forward to active theme (zero view changes)
- [ ] Move semantic colors to Asset Catalog (WidgetKit requirement)
- [ ] Set up App Group (`group.com.prodnote.shared`) for widget theme sharing

### Theme Designs
- [ ] Default theme (current app look — free)
- [ ] Dark theme (free)
- [ ] At least 3 paid premium themes designed (colors, typography, style)
- [ ] Each theme tested on both iPhone and iPad

### Theme Picker UI
- [ ] ThemeView replaced with real picker (swatches, live preview, select)
- [ ] Selected theme applies instantly across the whole app
- [ ] Theme persists after app is killed and reopened
- [ ] Picker looks correct on both iPhone and iPad

### Background Image Support
- [ ] User can set a photo from their library as app background
- [ ] Background scales and fits correctly on iPhone (all sizes)
- [ ] Background scales and fits correctly on iPad (all sizes)
- [ ] Background applies across all screens consistently
- [ ] Background works in both light and dark mode
- [ ] Background is saved and restored on relaunch

### Paywall
- [ ] Free tier: Default + Dark themes only
- [ ] Paid theme packs: $1.99 per pack
- [ ] Pro bundle: all packs (current + future) — $7.99 one-time
- [ ] StoreKit integration for in-app purchases
- [ ] Purchased themes persist and restore correctly

---

## Priority 3 — Widgets (V1, iPhone + iPad)
Full widget designs that inherit the active theme automatically.

### Widget Infrastructure
- [ ] Add Widget Extension target to Xcode project
- [ ] Set up App Group so widget reads active theme from ThemeManager
- [ ] Widget reads same background/colors as the app

### Home Screen Widgets (iPhone + iPad)
- [ ] Small widget (2x2) — recent note or task count
- [ ] Medium widget (4x2) — recent tasks list
- [ ] Large widget (4x4) — expanded task list or note preview
- [ ] All sizes themed: colors + background match active app theme
- [ ] Widget taps deep link into the correct note/task in the app

### Lock Screen Widgets (iPhone)
- [ ] Circular widget — task count or streak
- [ ] Rectangular widget — most recent task title
- [ ] Inline widget — quick note count

### Widget Polish
- [ ] All widgets update when theme changes in the app
- [ ] All widgets look correct in Light Mode
- [ ] All widgets look correct in Dark Mode
- [ ] All widgets look correct in iOS 18 Tinted mode
- [ ] No stale/broken data shown when widget first loads

---

## Priority 4 — Apple Developer Program + iCloud Setup
- [ ] Enroll at developer.apple.com/programs/enroll ($99/year)
- [ ] Xcode → Note-taking target → Signing & Capabilities → add iCloud
- [ ] Check the CloudKit checkbox
- [ ] Commit the auto-generated Note-taking.entitlements file
- [ ] iCloud sync: notes appear on a second device (iPhone + iPad)

---

## Priority 5 — Branding
- [ ] Design and finalize app logo (1024x1024 px)
- [ ] Add all required icon sizes in Xcode Assets catalog
- [ ] Choose final app name (confirm "Note-taking" or rename)

---

## Priority 6 — App Store Screenshots
Showcase the themes and widgets. Capture both iPhone and iPad.

- [ ] Screenshot: Home / Folders screen
- [ ] Screenshot: Task list view
- [ ] Screenshot: Note editor with formatting toolbar
- [ ] Screenshot: Slash command `/` menu open
- [ ] Screenshot: Theme picker showing paid theme options
- [ ] Screenshot: Widget on home screen with active theme
- [ ] Screenshot: Calendar event created from a note
- [ ] Minimum: 3 screenshots — iPhone 6.9"
- [ ] Minimum: 3 screenshots — iPhone 6.5"
- [ ] Minimum: 3 screenshots — iPad Pro 13"

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
| Name | Tier | Audience | Color Direction |
|---|---|---|---|
| Default | Free | Everyone | Warm off-white (current look) |
| Midnight | Free | Everyone | Deep charcoal (current dark) |
| Academia | Paid | Millennial women, students | Warm sepia, cream, deep brown |
| Nord | Paid | Men, professionals | Arctic blue-grey, icy white |
| Tokyo Night | Paid | Gen Z, creatives | Deep navy, neon purple, electric teal |
| Forest | Paid | Creatives, nature lovers | Muted green, earthy brown, amber |
| Rosé | Paid | Women 20–35 | Dusty rose, warm pink, cream |
| Void | Paid (bundle) | Power users, OLED screens | Pure #000000 black |

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

---

## Priority 7 — Final Submission
- [ ] Write App Store description and keywords (highlight themes + widgets)
- [ ] Set correct Bundle ID in Xcode
- [ ] Set version number (1.0.0) and build number (1)
- [ ] Archive the app (Product → Archive)
- [ ] Upload to App Store Connect via Xcode Organizer
- [ ] Fill in App Store Connect listing (description, category, age rating)
- [ ] Submit for Apple Review
