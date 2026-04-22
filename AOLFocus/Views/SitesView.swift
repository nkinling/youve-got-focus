import SwiftUI

struct SitesView: View {
    @EnvironmentObject var session: FocusSession
    @State private var newSite: String = ""

    private let defaultSites = [
        "Disney+", "Facebook", "Hulu",
        "Instagram", "LinkedIn", "Netflix",
        "Pinterest", "Reddit", "TikTok",
        "Twitch", "X (Twitter)", "YouTube"
    ]

    var body: some View {
        VStack(spacing: 8) {
            FocusLogoView()
                .padding(.bottom, 4)

            Win95Panel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Blocked Sites")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.win95Blue)

                    // Always Blocked
                    Text("Always Blocked:")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.win95Text)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(defaultSites, id: \.self) { site in
                                Text(site)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.win95Text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                    .frame(height: 106)
                    .background(Color(red: 237/255, green: 237/255, blue: 237/255))
                    .win95Sunken()

                    // Custom Blocked
                    Text("Also Blocked:")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.win95Text)

                    if session.customBlockedSites.isEmpty {
                        Text("No sites added")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(white: 0.55))
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
                            .background(Color(red: 237/255, green: 237/255, blue: 237/255))
                            .win95Sunken()
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(session.customBlockedSites.enumerated()), id: \.offset) { i, site in
                                    HStack {
                                        Text(site)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.win95Text)
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
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                        .frame(height: 70)
                        .background(Color(red: 237/255, green: 237/255, blue: 237/255))
                        .win95Sunken()
                    }

                    // Add site row
                    HStack(spacing: 6) {
                        Win95Input(placeholder: "Example.com", text: $newSite)
                        Button {
                            addSite()
                        } label: {
                            Text("+ ADD")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                                .frame(height: 20)
                                .padding(.horizontal, 12)
                                .background(Color.win95Gray)
                                .win95Raised()
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.return, modifiers: [])
                    }
                }
            }

            Win95Button(title: "◄ BACK") {
                session.activeScreen = session.state == .active || session.state == .paused
                    ? .session : .login
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
