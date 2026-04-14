import SwiftUI

struct SitesView: View {
    @EnvironmentObject var session: FocusSession
    @State private var newSite: String = ""

    private let defaultSites = [
        "reddit.com", "twitter.com", "x.com", "youtube.com",
        "instagram.com", "facebook.com", "tiktok.com", "twitch.tv",
        "news.ycombinator.com", "linkedin.com"
    ]

    var body: some View {
        VStack(spacing: 8) {
            Win95Panel(title: "🚫 Manage Blocked Sites") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Default sites always blocked:")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.win95Dark)

                    // Default sites (read-only)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 1) {
                            ForEach(defaultSites, id: \.self) { site in
                                HStack {
                                    Text("🔒 \(site)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.win95Dark)
                                    Spacer()
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(height: 80)
                    .background(Color.white.opacity(0.5))
                    .win95Sunken()

                    Text("Custom blocked sites:")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.win95Dark)
                        .padding(.top, 4)

                    // Custom sites (editable)
                    if session.customBlockedSites.isEmpty {
                        Text("No custom sites. Add below.")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.win95Dark)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(Color.white)
                            .win95Sunken()
                            .frame(height: 50)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 1) {
                                ForEach(Array(session.customBlockedSites.enumerated()), id: \.offset) { i, site in
                                    HStack {
                                        Text(site)
                                            .font(.system(size: 10, design: .monospaced))
                                        Spacer()
                                        Button {
                                            session.removeCustomSite(at: i)
                                        } label: {
                                            Text("✕")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.win95Red)
                                                .frame(width: 18, height: 14)
                                                .background(Color.win95Gray)
                                                .win95Raised()
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                        .frame(height: 50)
                        .background(Color.white)
                        .win95Sunken()
                    }

                    // Add site input
                    HStack(spacing: 4) {
                        Win95Input(placeholder: "example.com", text: $newSite)
                        Button {
                            addSite()
                        } label: {
                            Text("+ Add")
                                .font(.system(size: 10, design: .monospaced))
                                .frame(height: 18)
                                .padding(.horizontal, 8)
                                .background(Color.win95Gray)
                                .win95Raised()
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.return, modifiers: [])
                    }
                }
            }

            HStack(spacing: 4) {
                Win95Button(title: "◄ Back") {
                    session.activeScreen = session.state == .active || session.state == .paused
                        ? .session : .login
                }
            }
        }
        .onSubmit { addSite() }
    }

    private func addSite() {
        guard !newSite.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        session.addCustomSite(newSite)
        newSite = ""
    }
}
