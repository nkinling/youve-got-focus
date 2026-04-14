import SwiftUI

struct LoginView: View {
    @EnvironmentObject var session: FocusSession
    @State private var password: String = ""

    var body: some View {
        VStack(spacing: 8) {
            // Logo
            FocusLogoView()
                .padding(.bottom, 4)

            // Login panel
            Win95Panel {
                VStack(alignment: .leading, spacing: 10) {
                    // Section header
                    Text("Sign On")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.win95Blue)

                    // Screen Name
                    HStack {
                        Text("Screen Name:")
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 100, alignment: .leading)
                        Win95Input(placeholder: "FocusWarrior99", text: $session.screenName)
                    }

                    // Password (cosmetic)
                    HStack {
                        Text("Password:")
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 100, alignment: .leading)
                        Win95Input(placeholder: "••••••••", text: $password, isPassword: true)
                    }

                    // Session length
                    HStack(spacing: 4) {
                        Text("Session:")
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 100, alignment: .leading)
                        Button {
                            if session.sessionMinutes > 5 { session.sessionMinutes -= 5 }
                        } label: {
                            Text("−")
                                .font(Font.custom("VT323", size: 16).fallback("Courier New"))
                                .frame(width: 20, height: 20)
                                .background(Color.win95Gray)
                                .win95Raised()
                        }
                        .buttonStyle(.plain)

                        Text("\(session.sessionMinutes)")
                            .font(Font.custom("VT323", size: 16).fallback("Courier New"))
                            .foregroundColor(.win95Blue)
                            .frame(width: 44, height: 20)
                            .background(Color.white)
                            .win95Sunken()
                            .multilineTextAlignment(.center)

                        Button {
                            if session.sessionMinutes < 120 { session.sessionMinutes += 5 }
                        } label: {
                            Text("+")
                                .font(Font.custom("VT323", size: 16).fallback("Courier New"))
                                .frame(width: 20, height: 20)
                                .background(Color.win95Gray)
                                .win95Raised()
                        }
                        .buttonStyle(.plain)
                    }

                    // Checkboxes
                    VStack(alignment: .leading, spacing: 6) {
                        CheckRow(label: "Enable dial-up slow mode", isOn: $session.slowModeEnabled)
                        CheckRow(label: "Block distracting sites", isOn: $session.blockSitesEnabled)
                        CheckRow(label: "Enable sounds", isOn: $session.soundsEnabled)
                    }
                }
            }

            // Connecting animation (shown mid-dial)
            if session.activeScreen == .connecting {
                ConnectingView()
            }

            // Sign On button
            if session.activeScreen != .connecting {
                Button {
                    startConnection()
                } label: {
                    Text("SIGN ON")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.win95Blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(Color.win95Gray)
                        .win95Raised()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func startConnection() {
        session.savePreferences()
        session.startSession()

        if session.soundsEnabled {
            session.sounds.playDialup {
                session.onConnected()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                session.onConnected()
            }
        }
    }
}

// MARK: - Focus Logo

struct FocusLogoView: View {
    var body: some View {
        VStack(spacing: 4) {
            // Triangle with globe
            ZStack {
                TriangleShape()
                    .fill(Color.win95Blue)
                    .frame(width: 90, height: 78)
                Image(systemName: "globe")
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(.white)
                    .offset(y: 6)
            }

            // "YOU'VE GOT" spaced caps
            Text("Y O U ' V E   G O T")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.win95Blue)
                .tracking(1)

            // "Focus" in brush script
            Text("Focus")
                .font(Font.custom("Snell Roundhand", size: 48))
                .foregroundColor(.win95Blue)
        }
    }
}

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Connecting animation

struct ConnectingView: View {
    @EnvironmentObject var session: FocusSession
    @State private var progress: Double = 0
    @State private var progressLabel = "Connecting..."
    @State private var timer: Timer?

    private let allLines = [
        "ATDT 1-800-AOL-FOCUS",
        "CONNECT 56000",
        "~~~ATH0~~~ CARRIER DETECTED",
        "Verifying username...",
        "Loading Focus Module v5.0...",
        "Initializing Slow Mode™...",
        "Blocking distractions...",
        "YOU'VE GOT MINUTES!"
    ]

    private let stages = [
        "Initializing modem...", "Dialing...", "Handshaking...",
        "Authenticating...", "Loading Focus...", "Almost there...", "Connected!"
    ]

    var body: some View {
        VStack(spacing: 6) {
            Text("📞 Dialing AOL Focus...")
                .font(Font.custom("VT323", size: 18).fallback("Courier New"))
                .foregroundColor(.win95Blue)

            // Modem terminal
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(session.connectingLines.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.terminalGreen)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(idx)
                        }
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 80)
                .background(Color.black)
                .win95Sunken()
                .onChange(of: session.connectingLines.count) { count in
                    withAnimation { proxy.scrollTo(count - 1, anchor: .bottom) }
                }
            }

            // Progress bar
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white).frame(height: 16).win95Sunken()
                Rectangle().fill(Color.win95Blue)
                    .frame(width: max(0, progress / 100.0 * 358), height: 16)
                    .animation(.linear(duration: 0.3), value: progress)
                Text(progressLabel)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white)
                    .blendMode(.difference)
                    .frame(maxWidth: .infinity)
            }
        }
        .onAppear { startProgress() }
        .onDisappear { stopProgress() }
    }

    private func startProgress() {
        progress = 0
        session.connectingLines = [allLines[0]]

        var step = 0
        let t = Timer(timeInterval: 0.42, repeats: true) { t in
            step += 1
            let newProgress = min(100, Double(step) * 14.0)
            progress = newProgress
            let stageIdx = min(Int(newProgress / 15.0), stages.count - 1)
            progressLabel = stages[stageIdx]

            if step < allLines.count {
                session.connectingLines.append(allLines[step])
            }

            if progress >= 100 { t.invalidate() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopProgress() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Checkbox row

struct CheckRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 6) {
            Button {
                isOn.toggle()
            } label: {
                ZStack {
                    Rectangle().fill(Color.white).frame(width: 13, height: 13).win95Sunken()
                    if isOn {
                        Text("✓")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.win95Blue)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .onTapGesture { isOn.toggle() }
        }
    }
}
