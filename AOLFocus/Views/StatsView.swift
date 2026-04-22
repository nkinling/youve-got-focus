import SwiftUI

struct StatsView: View {
    @EnvironmentObject var session: FocusSession

    private var totalMins: Int { session.totalFocusSeconds / 60 }

    var body: some View {
        VStack(spacing: 8) {
            FocusLogoView()
                .padding(.bottom, 4)

            Win95Panel {
                VStack(spacing: 0) {
                    Text("Statistics")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.win95Blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 10)

                    statRow(label: "Sessions:", value: "\(session.sessionsCompleted)")
                    statRow(label: "Average Session:", value: "\(session.statsAverageMinutes) minutes")
                    statRow(label: "Total Focus Time:", value: "\(totalMins) minutes")
                    statRow(label: "Focus Streak:", value: "\(session.focusStreak) days")

                    Text("Keep dialing up to stay focused")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.win95Text)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 12)
                }
            }

            HStack(spacing: 4) {
                Win95Button(title: "◄ BACK") {
                    session.activeScreen = session.state == .active || session.state == .paused
                        ? .session : .login
                }
                Win95Button(title: "🗑 CLEAR", danger: true) {
                    session.clearStats()
                }
            }
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.win95Text)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.win95Blue)
        }
        .padding(.vertical, 6)
        .overlay(Divider(), alignment: .bottom)
    }
}
