import SwiftUI
import EventKit
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "Onboarding")

// MARK: - PermissionOnboardingView
//
// Pre-permission onboarding screen shown on first launch.
//
// Apple HIG guidance:
//   • Never fire the system permission dialog cold — show a custom screen first
//     that explains the benefit so the user is more likely to tap Allow.
//   • On iPhone:  fill the screen (large sheet detent, no drag handle).
//   • On iPad:    compact form-style card (not full-screen — avoids the "big-ass window").
//   • On Mac:     standard panel sheet.
//
// Pages:
//   0 — Welcome      (always shown)
//   1 — Calendar     (skipped if permission was already decided — existing installs)
//   2 — Done         (always shown)
//
// Triggered from ContentView via @AppStorage("onboardingV1Complete").

struct PermissionOnboardingView: View {

    /// Called when the user finishes or skips all steps.
    var onComplete: () -> Void

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(ThemeManager.self)     private var themeManager

    private var isRegular: Bool { hSizeClass == .regular }

    @State private var page: Int = 0
    @State private var calendarAlreadyDecided: Bool = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background follows app theme exactly
            themeManager.current.screenBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Progress dots ────────────────────────────────────────────
                progressDots
                    .padding(.top, isRegular ? 28 : 20)
                    .padding(.bottom, 4)

                // ── Page content ─────────────────────────────────────────────
                TabView(selection: $page) {
                    WelcomePage(onContinue: advance)
                        .tag(0)

                    CalendarPermissionPage(
                        onAllow: {
                            log.info("Onboarding: user tapped Allow Calendar")
                            Task {
                                await CalendarPermissionService.shared.requestIfNeeded()
                                log.info("Onboarding: calendar result = \(CalendarPermissionService.shared.isGranted)")
                                await MainActor.run { advance() }
                            }
                        },
                        onSkip: {
                            log.info("Onboarding: user skipped Calendar")
                            advance()
                        }
                    )
                    .tag(1)

                    DonePage(onFinish: {
                        log.info("Onboarding: complete — dismissing")
                        onComplete()
                    })
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: page)
            }
        }
        .onAppear {
            // Detect existing users who already decided on calendar permission.
            // On their first launch after this update, skip the calendar page.
            let status = EKEventStore.authorizationStatus(for: .event)
            calendarAlreadyDecided = (status != .notDetermined)
            log.info("Onboarding appeared — calendarStatus=\(String(describing: status)) alreadyDecided=\(calendarAlreadyDecided)")
        }
        // ── Adaptive sheet sizing ─────────────────────────────────────────────
        // iPhone:  large detent = full screen, no swipe-to-dismiss
        // iPad:    form-style compact card (iOS 18) or fixed height (iOS 16–17)
        // Mac:     default sheet behaviour
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
        .modifier(OnboardingPresentationSizing(isRegular: isRegular))
    }

    // MARK: - Helpers

    private func advance() {
        let next: Int
        if page == 0 && calendarAlreadyDecided {
            // Calendar permission already resolved — skip straight to Done
            log.debug("Onboarding: skipping calendar page (already decided)")
            next = 2
        } else {
            next = min(page + 1, 2)
        }
        log.debug("Onboarding: page \(page) → \(next)")
        withAnimation(.easeInOut(duration: 0.35)) { page = next }
    }

    // MARK: - Progress dots

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(calendarAlreadyDecided ? [0, 2] : [0, 1, 2], id: \.self) { idx in
                // Map visible dot index to actual page index
                let actualPage = calendarAlreadyDecided ? (idx == 0 ? 0 : 2) : idx
                Circle()
                    .fill(page == actualPage
                          ? Color.themeAccent
                          : Color.secondaryText.opacity(0.3))
                    .frame(width: 7, height: 7)
                    .animation(.easeInOut(duration: 0.2), value: page)
            }
        }
    }
}

// MARK: - Adaptive sizing modifier

/// Applies the correct sheet-sizing strategy per device.
private struct OnboardingPresentationSizing: ViewModifier {
    let isRegular: Bool

    func body(content: Content) -> some View {
        if isRegular {
            // iPad / Mac — compact card, not full-screen
            if #available(iOS 18, *) {
                content
                    .presentationSizing(.form)
            } else {
                content
                    .presentationDetents([.height(620)])
            }
        } else {
            // iPhone — fill the screen
            content
                .presentationDetents([.large])
        }
    }
}

// MARK: - Page 0: Welcome

private struct WelcomePage: View {
    var onContinue: () -> Void

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isRegular: Bool { hSizeClass == .regular }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── App icon ─────────────────────────────────────────────────────
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.themeAccent.gradient)
                    .frame(width: 80, height: 80)
                Image(systemName: "checklist")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: Color.themeAccent.opacity(0.4), radius: 12, x: 0, y: 6)
            .padding(.bottom, 28)

            // ── Title ────────────────────────────────────────────────────────
            Text("Welcome to ProdNote")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

            // ── Subtitle ─────────────────────────────────────────────────────
            Text("Your smart to-do list that works with your calendar, your voice, and your life.")
                .font(.system(size: 17))
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            Spacer()
            Spacer()

            // ── CTA button ───────────────────────────────────────────────────
            Button(action: onContinue) {
                Text("Get Started")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.themeAccent, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, isRegular ? 28 : 44)
        }
    }
}

// MARK: - Page 1: Calendar permission

private struct CalendarPermissionPage: View {
    var onAllow: () -> Void
    var onSkip:  () -> Void

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isRegular: Bool { hSizeClass == .regular }

    private let benefits: [(icon: String, text: String)] = [
        ("calendar.badge.plus",    "Tasks with dates appear automatically in Apple Calendar"),
        ("bell.badge",             "Get reminded at exactly the right time"),
        ("arrow.triangle.2.circlepath", "Stays in sync across all your Apple devices"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Icon ─────────────────────────────────────────────────────────
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.themeAccent.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color.themeAccent)
            }
            .padding(.bottom, 24)

            // ── Title ─────────────────────────────────────────────────────────
            Text("Add Tasks to Your Calendar")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 10)

            // ── Description ───────────────────────────────────────────────────
            Text("ProdNote can create calendar events from your tasks automatically — no copy-pasting needed.")
                .font(.system(size: 15))
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 28)

            // ── Benefit list ──────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 14) {
                ForEach(benefits, id: \.text) { item in
                    HStack(spacing: 14) {
                        Image(systemName: item.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.themeAccent)
                            .frame(width: 24)

                        Text(item.text)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()

            // ── Allow button ──────────────────────────────────────────────────
            Button(action: onAllow) {
                Text("Allow Calendar Access")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.themeAccent, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // ── Skip link ─────────────────────────────────────────────────────
            Button(action: onSkip) {
                Text("Not Now")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.secondaryText)
            }
            .buttonStyle(.plain)
            .padding(.bottom, isRegular ? 28 : 36)
        }
    }
}

// MARK: - Page 2: Done

private struct DonePage: View {
    var onFinish: () -> Void

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isRegular: Bool { hSizeClass == .regular }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Checkmark icon ────────────────────────────────────────────────
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.themeAccent)
                .padding(.bottom, 24)

            // ── Title ─────────────────────────────────────────────────────────
            Text("You're all set!")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.primaryText)
                .padding(.bottom, 12)

            // ── Body ──────────────────────────────────────────────────────────
            Text("ProdNote is ready. Tap any task to add notes, voice recordings, photos, or files.")
                .font(.system(size: 17))
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            Spacer()
            Spacer()

            // ── Let's go button ───────────────────────────────────────────────
            Button(action: onFinish) {
                Text("Let's go")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.themeAccent, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, isRegular ? 28 : 44)
        }
    }
}
