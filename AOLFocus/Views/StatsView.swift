import SwiftUI
import AppKit

struct StatsView: View {
    @EnvironmentObject var session: FocusSession

    private var totalHours: Int { session.totalFocusSeconds / 3600 }
    private var totalMins: Int { (session.totalFocusSeconds % 3600) / 60 }

    var body: some View {
        VStack(spacing: 8) {
            Win95Panel(title: "📊 Session Statistics") {
                VStack(spacing: 0) {
                    statRow(label: "Sessions Completed:", value: "\(session.sessionsCompleted)")
                    statRow(label: "Total Focus Time:", value: "\(totalHours)h \(totalMins)m")
                    statRow(label: "Average Session:", value: "\(session.statsAverageMinutes)m")

                    Text("Keep logging in to build your streak!")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.win95Dark)
                        .italic()
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            HStack(spacing: 4) {
                Win95Button(title: "◄ Back") {
                    session.activeScreen = session.state == .active || session.state == .paused
                        ? .session : .login
                }
                Win95Button(title: "🗑 Clear Stats", danger: true) {
                    let alert = NSAlert()
                    alert.messageText = "Clear All Statistics?"
                    alert.informativeText = "This cannot be undone."
                    alert.addButton(withTitle: "Clear")
                    alert.addButton(withTitle: "Cancel")
                    if alert.runModal() == .alertFirstButtonReturn {
                        session.clearStats()
                    }
                }
            }
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
            Spacer()
            Text(value)
                .font(Font.custom("VT323", size: 18).fallback("Courier New"))
                .foregroundColor(.win95Blue)
        }
        .padding(.vertical, 3)
        .overlay(Divider(), alignment: .bottom)
    }
}
