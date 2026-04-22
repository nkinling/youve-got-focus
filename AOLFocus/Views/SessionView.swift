import SwiftUI
import AppKit

struct SessionView: View {
    @EnvironmentObject var session: FocusSession

    private var timerColor: Color {
        if session.state == .complete        { return .win95Green }
        if session.remainingSeconds < 60     { return Color(red: 0.5, green: 0.25, blue: 0) }
        return .win95Blue
    }

    private var progress: Double {
        guard session.totalSeconds > 0 else { return 0 }
        let elapsed = session.totalSeconds - session.remainingSeconds
        return min(1.0, max(0.0, Double(elapsed) / Double(session.totalSeconds)))
    }

    private var statusLine: String {
        if session.state == .paused  { return "Session paused • Resume when ready" }
        if session.state == .complete { return "Session complete — great work!" }
        return "56kbps Connection  •  Max Focus Speed"
    }

    var body: some View {
        VStack(spacing: 8) {
            FocusLogoView()
                .padding(.bottom, 4)

            Win95Panel {
                VStack(spacing: 16) {
                    // Header
                    Text("Dial-Up Focus Session")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.win95Blue)
                        .frame(maxWidth: .infinity, alignment: .center)

                    // Timer
                    Text(session.state == .complete ? (flashText ? "BYE! 👋" : "✓ DONE") : session.timerString)
                        .font(.system(size: 64, weight: .regular).monospacedDigit())
                        .foregroundColor(timerColor)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .animation(session.remainingSeconds < 60 ? .easeInOut(duration: 0.5).repeatForever() : .none, value: timerColor)

                    // Progress bar
                    SessionProgressBar(progress: progress)

                    // Status line
                    Text(statusLine)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.win95Text)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(8)
            }

            // Buttons
            HStack(spacing: 8) {
                Win95Button(title: session.state == .paused ? "▶ RESUME" : "⏸ PAUSE") {
                    if session.state == .active { session.pause() }
                    else if session.state == .paused { session.resume() }
                }
                Win95Button(title: "📞 SIGN OFF", danger: true) {
                    session.signOff()
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
}

// MARK: - Progress Bar

struct SessionProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Rectangle()
                    .fill(Color(red: 237/255, green: 237/255, blue: 237/255))
                    .frame(height: 8)

                // Elapsed (blue fill)
                Rectangle()
                    .fill(Color.win95Blue)
                    .frame(width: geo.size.width * CGFloat(progress), height: 8)
            }
        }
        .frame(height: 8)
    }
}
