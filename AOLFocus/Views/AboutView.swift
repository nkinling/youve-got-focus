import SwiftUI
import AppKit

struct AboutView: View {
    @EnvironmentObject var session: FocusSession

    private let body1 = """
You've Got Focus is a nostalgic productivity \
timer inspired by the dial-up days of the \
90s internet era.
"""
    private let body2 = """
It recreates the slog of a 56 kbps internet \
connection, intentionally slowing your \
browser to cut through the noise and keep \
you focused.
"""
    private let body3 = "Dial up, and stay dialed in."

    var body: some View {
        VStack(spacing: 8) {
            FocusLogoView()
                .padding(.bottom, 4)

            Win95Panel {
                VStack(alignment: .leading, spacing: 16) {
                    Text("About")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.win95Blue)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(body1)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.win95Text)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(body2)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.win95Text)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(body3)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.win95Text)
                    }
                }
            }

            HStack(spacing: 8) {
                Win95Button(title: "◄ BACK") {
                    session.activeScreen = session.state == .active || session.state == .paused
                        ? .session : .login
                }
                Win95Button(title: "✉ CONTACT") {
                    if let url = URL(string: "mailto:hello@youvegetfocus.com") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}
