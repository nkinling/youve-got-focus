import SwiftUI
import AppKit

struct SessionView: View {
    @EnvironmentObject var session: FocusSession

    private var timerColor: Color {
        if session.remainingSeconds < 60  { return .win95Red }
        if session.remainingSeconds < 300 { return Color(red: 0.5, green: 0.25, blue: 0) }
        return .win95Blue
    }

    private var warnText: String {
        if session.remainingSeconds <= 0   { return "✓ SESSION COMPLETE — GREAT WORK!" }
        if session.remainingSeconds < 60   { return "⚠ LESS THAN 1 MINUTE — FINAL STRETCH!" }
        if session.remainingSeconds < 300  { return "Under 5 minutes — keep pushing!" }
        if session.state == .paused        { return "Session paused. Resume when ready." }
        return "Slow Mode active. Pages load slower. Stay focused!"
    }

    var body: some View {
        VStack(spacing: 8) {
            Win95Panel(title: "⏰ Dial-Up Session Active") {
                VStack(spacing: 6) {
                    // Big timer
                    Text(session.state == .complete ? (flashText ? "BYE! 👋" : "✓ DONE") : session.timerString)
                        .font(Font.custom("VT323", size: 56).fallback("Courier New"))
                        .foregroundColor(session.state == .complete ? .win95Green : timerColor)
                        .tracking(4)
                        .shadow(color: .win95Dark, radius: 0, x: 1, y: 1)
                        .animation(session.remainingSeconds < 60 ? .easeInOut(duration: 0.5).repeatForever() : .none, value: timerColor)

                    Text("MINUTES REMAINING · 28.8 KBPS CONNECTION")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.win95Dark)

                    // Status row
                    HStack(spacing: 6) {
                        Circle()
                            .fill(session.state == .paused ? Color.win95Dark : Color.win95Green)
                            .frame(width: 8, height: 8)
                            .shadow(color: session.state == .paused ? .clear : .win95Green, radius: 3)
                            .animation(session.state == .active ? .easeInOut(duration: 1).repeatForever() : .none, value: session.state)

                        Text(session.state == .paused
                             ? "Paused — session on hold"
                             : "Connected · Slow Mode \(session.slowModeEnabled ? "ON" : "OFF")")
                            .font(.system(size: 10, design: .monospaced))
                    }

                    // Speed bar
                    Text("Connection Speed: ████░░░░░░ 28.8 kbps (simulated)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.win95Dark)

                    AnimatedSpeedBar()

                    // Warning box
                    HStack(alignment: .top, spacing: 4) {
                        Text("⚠️")
                        Text(warnText)
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.win95Yellow)
                    .overlay(Rectangle().stroke(Color(red: 0.5, green: 0.5, blue: 0), lineWidth: 1))

                    // Buddy list
                    BuddyList()
                }
            }

            // Buttons
            HStack(spacing: 4) {
                Win95Button(title: session.state == .paused ? "▶ Resume" : "⏸ Pause") {
                    if session.state == .active { session.pause() }
                    else if session.state == .paused { session.resume() }
                }
                Win95Button(title: "🚫 Sites") {
                    session.activeScreen = .sites
                }
                Win95Button(title: "📊 Stats") {
                    session.activeScreen = .stats
                }
                Win95Button(title: "🚪 Sign Off", danger: true) {
                    confirmSignOff()
                }
            }
        }
        .onAppear { startFlashIfComplete() }
    }

    // MARK: - Flash animation for session complete

    @State private var flashText = false
    @State private var flashTimer: Timer?

    private func startFlashIfComplete() {
        guard session.state == .complete else { return }
        var count = 0
        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { t in
            flashText.toggle()
            count += 1
            if count > 8 {
                t.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    session.state = .idle
                    session.activeScreen = .login
                }
            }
        }
        if session.soundsEnabled {
            session.sounds.playGoodbye()
        }
    }

    private func confirmSignOff() {
        let alert = NSAlert()
        alert.messageText = "Sign Off AOL Focus?"
        alert.informativeText = "Your session will end early."
        alert.addButton(withTitle: "Sign Off")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            session.signOff()
        }
    }
}

// MARK: - Animated Speed Bar

struct AnimatedSpeedBar: View {
    @State private var offset: CGFloat = 0
    @State private var isPaused = false
    @EnvironmentObject var session: FocusSession

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(Color.white).frame(height: 12).win95Sunken()
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .win95Blue, location: 0),
                            .init(color: .win95Blue, location: 0.5),
                            .init(color: .win95LtBlue, location: 0.5),
                            .init(color: .win95LtBlue, location: 1)
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: 200, height: 12)
                .offset(x: offset)
                .clipped()
        }
        .frame(height: 12)
        .clipped()
        .onChange(of: session.state) { newState in
            isPaused = (newState == .paused)
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                offset = 24
            }
        }
    }
}

// MARK: - Buddy List

struct BuddyList: View {
    @EnvironmentObject var session: FocusSession

    private let defaultSites = [
        "Reddit", "Twitter/X", "YouTube", "Instagram",
        "Facebook", "TikTok", "Twitch", "HackerNews"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("📋 Buddy List — Focus Mode")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.win95Blue)
            }
            .padding(.bottom, 2)
            .overlay(Divider(), alignment: .bottom)

            // You (online)
            HStack(spacing: 4) {
                Text("🟢").font(.system(size: 10))
                Text("\(session.screenName) (you — online)")
                    .font(.system(size: 10, design: .monospaced))
            }

            // Blocked sites as "offline"
            let blocked = defaultSites + session.customBlockedSites.map { $0.capitalized }
            ForEach(blocked.prefix(6), id: \.self) { site in
                HStack(spacing: 4) {
                    Text("⚫").font(.system(size: 10))
                    Text("\(site) (blocked)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.win95Dark)
                }
            }
            if blocked.count > 6 {
                Text("…+\(blocked.count - 6) more blocked")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.win95Dark)
                    .italic()
            }
        }
        .padding(.top, 4)
        .overlay(Divider(), alignment: .top)
    }
}
