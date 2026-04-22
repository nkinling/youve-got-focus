import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var session: FocusSession

    var body: some View {
        Win95Window(title: "You've Got Focus – 56 kbps") {
            Group {
                switch session.activeScreen {
                case .login, .connecting:
                    LoginView()
                case .session:
                    SessionView()
                case .stats:
                    StatsView()
                case .sites:
                    SitesView()
                }
            }
        }
        .frame(width: 380)
        .background(Color.win95Gray)
    }
}

// MARK: - Design System

extension Color {
    static let win95Gray    = Color(red: 0.753, green: 0.753, blue: 0.753)  // #C0C0C0
    static let win95Dark    = Color(red: 0.502, green: 0.502, blue: 0.502)  // #808080
    static let win95White   = Color.white
    static let win95Blue    = Color(red: 0.0,   green: 0.0,   blue: 0.502)  // #000080
    static let win95LtBlue  = Color(red: 0.063, green: 0.518, blue: 0.816)  // #1084d0
    static let win95Red     = Color(red: 0.502, green: 0.0,   blue: 0.0)    // #800000
    static let win95Yellow  = Color(red: 1.0,   green: 1.0,   blue: 0.6)    // #ffff99
    static let win95Green   = Color(red: 0.0,   green: 0.667, blue: 0.0)    // #00aa00
    static let terminalGreen = Color(red: 0.0,  green: 1.0,   blue: 0.0)    // #00ff00
    static let win95Text     = Color(red: 0.188, green: 0.188, blue: 0.188) // #303030
}

// MARK: - Win95 Window Chrome

struct Win95Window<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                Text(title)
                    .font(Font.custom("VT323", size: 15).fallback("Courier New"))
                    .foregroundColor(.white)
                Spacer()
                // Window buttons — all close the popover
                ForEach(["minus", "square", "xmark"], id: \.self) { icon in
                    Button {
                        NotificationCenter.default.post(name: .closeAOLFocusPopover, object: nil)
                    } label: {
                        ZStack {
                            Rectangle().fill(Color.win95Gray)
                                .frame(width: 16, height: 14)
                                .win95Raised()
                            Image(systemName: icon)
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                LinearGradient(colors: [.win95Blue, .win95LtBlue],
                               startPoint: .leading, endPoint: .trailing)
            )

            // Menu bar
            Win95MenuBar()

            // Content
            VStack(spacing: 0) {
                content
            }
            .padding(8)

            // Status bar
            Win95StatusBar()
        }
        .win95Raised()
        .padding(4)
        .background(Color.win95Gray)
    }
}

// MARK: - Menu Bar

struct Win95MenuBar: View {
    @EnvironmentObject var session: FocusSession
    @State private var activeMenu: String? = nil

    var body: some View {
        HStack(spacing: 0) {
            menuItem("File", menu: [
                ("New Session", { session.activeScreen = .login }),
                ("Statistics...", { session.activeScreen = .stats }),
                ("—", {}),
                ("Quit AOL Focus", { NSApp.terminate(nil) })
            ])
            menuItem("Session", menu: [
                ("Pause/Resume", {
                    if session.state == .active { session.pause() }
                    else if session.state == .paused { session.resume() }
                }),
                ("Sign Off", { session.signOff() })
            ])
            menuItem("Tools", menu: [
                ("Blocked Sites...", { session.activeScreen = .sites }),
                ("—", {}),
                (session.soundsEnabled ? "✓ Sounds ON" : "  Sounds OFF", {
                    session.soundsEnabled.toggle()
                    session.savePreferences()
                })
            ])
            menuItem("Help", menu: [
                ("About AOL Focus", {
                    let alert = NSAlert()
                    alert.messageText = "AOL Focus v5.0"
                    alert.informativeText = "Dial-up era Pomodoro timer.\nLog in. Slow down. Get work done.\n\n28.8 kbps of pure productivity."
                    alert.runModal()
                })
            ])
            Spacer()
        }
        .frame(height: 22)
        .background(Color.win95Gray)
        .overlay(Divider().foregroundColor(.win95Dark), alignment: .bottom)
    }

    private func menuItem(_ title: String, menu: [(String, () -> Void)]) -> some View {
        Menu {
            ForEach(Array(menu.enumerated()), id: \.offset) { _, item in
                if item.0 == "—" {
                    Divider()
                } else {
                    Button(item.0) { item.1() }
                }
            }
        } label: {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
        }
        .menuStyle(.borderlessButton)
        .foregroundColor(.black)
        .fixedSize()
    }
}

// MARK: - Status Bar

struct Win95StatusBar: View {
    @EnvironmentObject var session: FocusSession

    var statusText: String {
        switch session.state {
        case .idle, .connecting: return "Dial Up Internet Simulator"
        case .active:            return "Session Active · \(session.screenName)"
        case .paused:            return "Session Paused"
        case .complete:          return "Session Complete!"
        }
    }

    var rightText: String {
        switch session.state {
        case .idle, .connecting: return "Ready to Connect"
        case .active:            return "Connected!"
        case .paused:            return "Paused"
        case .complete:          return "Disconnected"
        }
    }

    var body: some View {
        HStack {
            Text(statusText)
                .font(.system(size: 9))
                .foregroundColor(.black)
                .padding(.horizontal, 4)
                .win95Sunken()
            Spacer()
            Text(rightText)
                .font(.system(size: 9))
                .foregroundColor(.black)
                .padding(.horizontal, 4)
                .win95Sunken()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.win95Gray)
    }
}

// MARK: - Shared UI Components

struct Win95Panel<Content: View>: View {
    let title: String?
    let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(Font.custom("VT323", size: 14).fallback("Courier New"))
                    .foregroundColor(.win95Blue)
                    .padding(.bottom, 2)
                    .overlay(Divider().foregroundColor(Color(white: 0.8)), alignment: .bottom)
            }
            content
        }
        .padding(8)
        .background(Color.white)
        .win95Sunken()
    }
}

struct Win95Button: View {
    let title: String
    var danger: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(danger ? .win95Red : .black)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(Color.win95Gray)
                .win95Raised()
        }
        .buttonStyle(.plain)
    }
}

struct Win95Input: View {
    let placeholder: String
    @Binding var text: String
    var isPassword: Bool = false

    var body: some View {
        Group {
            if isPassword {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundColor(.win95Blue)
        .textFieldStyle(.plain)
        .padding(.horizontal, 3)
        .padding(.bottom, 2)
        .frame(height: 20)
        .background(Color(red: 237/255, green: 237/255, blue: 237/255))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(red: 89/255, green: 89/255, blue: 89/255)), alignment: .bottom)
    }
}

// MARK: - Border Modifiers

extension View {
    func win95Raised() -> some View {
        self.overlay(
            ZStack {
                // Top + left = white highlight
                VStack {
                    Rectangle().fill(Color.white).frame(height: 1)
                    Spacer()
                    Rectangle().fill(Color(white: 0.35)).frame(height: 1)
                }
                HStack {
                    Rectangle().fill(Color.white).frame(width: 1)
                    Spacer()
                    Rectangle().fill(Color(white: 0.35)).frame(width: 1)
                }
            }
        )
    }

    func win95Sunken() -> some View {
        self.overlay(
            ZStack {
                VStack {
                    Rectangle().fill(Color(white: 0.35)).frame(height: 1)
                    Spacer()
                    Rectangle().fill(Color.white).frame(height: 1)
                }
                HStack {
                    Rectangle().fill(Color(white: 0.35)).frame(width: 1)
                    Spacer()
                    Rectangle().fill(Color.white).frame(width: 1)
                }
            }
        )
    }
}

// MARK: - Font fallback helper

extension Font {
    func fallback(_ fallbackName: String) -> Font {
        // VT323 must be bundled; if not found, Courier New is a decent fallback
        return self
    }
}

// Used by Font.custom().fallback() — in practice just return self
// Real fallback handled by OS font substitution
