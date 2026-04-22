import SwiftUI

struct LoginView: View {
    @EnvironmentObject var session: FocusSession
    @State private var password: String = "••••••••••"

    var body: some View {
        if session.activeScreen == .connecting {
            ConnectingView()
        } else {
            loginForm
        }
    }

    private var loginForm: some View {
        VStack(spacing: 8) {
            FocusLogoView()
                .padding(.bottom, 4)

            Win95Panel {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sign On")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.win95Blue)

                    HStack {
                        Text("Screen Name:")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.win95Text)
                            .frame(width: 100, alignment: .leading)
                        Win95Input(placeholder: "FocusWarrior99", text: $session.screenName)
                    }

                    HStack {
                        Text("Password:")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.win95Text)
                            .frame(width: 100, alignment: .leading)
                        Win95Input(placeholder: "••••••••", text: $password, isPassword: true)
                    }

                    HStack(spacing: 4) {
                        Text("Session:")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.win95Text)
                            .frame(width: 100, alignment: .leading)
                        Button {
                            if session.sessionMinutes > 5 { session.sessionMinutes -= 5 }
                        } label: {
                            Text("−")
                                .font(Font.custom("VT323", size: 16).fallback("Courier New"))
                                .foregroundColor(.black)
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
                                .foregroundColor(.black)
                                .frame(width: 20, height: 20)
                                .background(Color.win95Gray)
                                .win95Raised()
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 0) {
                        Spacer().frame(width: 108)
                        VStack(alignment: .leading, spacing: 8) {
                            CheckRow(label: "Enable dial-up slow mode", isOn: $session.slowModeEnabled)
                            CheckRow(label: "Block distracting sites", isOn: $session.blockSitesEnabled)
                        }
                        Spacer()
                    }
                }
                .padding(8)
            }

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

    private func startConnection() {
        session.savePreferences()
        session.startSession()

        if session.soundsEnabled {
            session.sounds.playDialup {
                guard session.state == .connecting else { return }
                session.onConnected()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                guard session.state == .connecting else { return }
                session.onConnected()
            }
        }
    }
}

// MARK: - Focus Logo

struct FocusLogoView: View {
    var body: some View {
        Image("Logo")
            .resizable()
            .scaledToFit()
            .frame(width: 148)
    }
}

// MARK: - Connecting animation

struct ConnectingView: View {
    @EnvironmentObject var session: FocusSession
    @State private var stage: Int = 0
    @State private var timer: Timer?

    private var stageLabel: String {
        switch stage {
        case 0: return "Dialing..."
        case 1: return "Connecting..."
        default: return "Connected!"
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            FocusLogoView()
                .padding(.bottom, 4)

            Win95Panel {
                VStack(alignment: .leading, spacing: 12) {
                    Text(stageLabel)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.win95Blue)

                    HStack(spacing: 16) {
                        BuddyBox(asset: "BuddyStage1", showIcon: true)
                        BuddyBox(asset: "BuddyStage2", showIcon: stage >= 1)
                        BuddyBox(asset: "BuddyStage3", showIcon: stage >= 2, iconHeight: 68)
                    }

                    Text("Dial up, slow down, and stay focused")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.win95Text)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            Button {
                session.signOff()
            } label: {
                Text("CANCEL")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.win95Blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(Color.win95Gray)
                    .win95Raised()
            }
            .buttonStyle(.plain)
        }
        .onAppear { startAnimation() }
        .onDisappear { timer?.invalidate(); timer = nil }
    }

    private func startAnimation() {
        stage = 0
        var tick = 0
        let t = Timer(timeInterval: 1.1, repeats: true) { [weak session] t in
            tick += 1
            withAnimation(.easeIn(duration: 0.2)) { stage = tick }
            if tick == 2 {
                // 3rd buddy appears — play "You've Got Focus"
                if session?.soundsEnabled == true {
                    session?.sounds.playYouveGotFocus()
                }
                t.invalidate()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
}

// MARK: - Buddy icon box

struct BuddyBox: View {
    let asset: String
    let showIcon: Bool
    var iconHeight: CGFloat = 60

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 237/255, green: 237/255, blue: 237/255))
                .win95Sunken()

            if showIcon {
                Image(asset)
                    .resizable()
                    .scaledToFit()
                    .frame(height: iconHeight)
            }
        }
        .frame(width: 108, height: 108)
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
                    Rectangle()
                        .fill(Color(red: 237/255, green: 237/255, blue: 237/255))
                        .frame(width: 13, height: 13)
                        .overlay(
                            Rectangle()
                                .stroke(Color(red: 89/255, green: 89/255, blue: 89/255), lineWidth: 1)
                        )
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
                .foregroundColor(.win95Text)
                .onTapGesture { isOn.toggle() }
        }
    }
}
