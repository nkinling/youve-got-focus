import Foundation
import Combine

enum SessionState: Equatable {
    case idle
    case connecting
    case active
    case paused
    case complete
}

enum ActiveScreen {
    case login, connecting, session, stats, sites
}

class FocusSession: ObservableObject {
    @Published var state: SessionState = .idle
    @Published var remainingSeconds: Int = 25 * 60
    @Published var totalSeconds: Int = 25 * 60
    @Published var screenName: String = "FocusWarrior99"
    @Published var slowModeEnabled: Bool = true
    @Published var blockSitesEnabled: Bool = true
    @Published var soundsEnabled: Bool = true
    @Published var sessionMinutes: Int = 25
    @Published var activeScreen: ActiveScreen = .login
    @Published var customBlockedSites: [String] = []
    @Published var connectingProgress: Double = 0
    @Published var connectingLines: [String] = []

    // Stats
    @Published var sessionsCompleted: Int = 0
    @Published var totalFocusSeconds: Int = 0
    @Published var focusStreak: Int = 0

    private var timer: Timer?
    private var lastTickDate: Date?
    private let throttler = NetworkThrottler()
    private let blocker = SiteBlocker()
    let sounds = SoundEngine()

    private let bgQueue = DispatchQueue(label: "com.aolfocus.network", qos: .userInitiated)

    init() {
        loadPreferences()
        restoreSessionIfActive()
        warmUpProcessPool()
    }

    /// Spawn a trivial no-op process at launch so the dynamic linker and sandbox
    /// initialization cost is paid upfront, not on the first real shell command.
    private func warmUpProcessPool() {
        bgQueue.async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/bash")
            p.arguments = ["-c", "true"]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            try? p.run()
            p.waitUntilExit()
        }
    }

    // MARK: - Session Lifecycle

    func startSession() {
        state = .connecting
        activeScreen = .connecting
        totalSeconds = sessionMinutes * 60
        remainingSeconds = sessionMinutes * 60
        connectingProgress = 0
        connectingLines = ["ATDT 1-800-AOL-FOCUS"]
    }

    func onConnected() {
        state = .active
        activeScreen = .session
        lastTickDate = Date()
        saveSessionState()

        let sites = customBlockedSites
        let shouldBlock = blockSitesEnabled
        let shouldThrottle = slowModeEnabled
        bgQueue.async { [weak self] in
            guard let self else { return }
            if shouldBlock  { self.blocker.blockSites(customSites: sites) }
            if shouldThrottle { self.throttler.enableThrottling() }
        }

        startTimer()
    }

    func pause() {
        guard state == .active else { return }
        state = .paused
        stopTimer()
        throttler.disableThrottling()
        saveSessionState()
    }

    func resume() {
        guard state == .paused else { return }
        state = .active
        lastTickDate = Date()
        saveSessionState()
        if slowModeEnabled { throttler.enableThrottling() }
        startTimer()
    }

    func signOff() {
        sounds.stopAll()
        endSession(completed: false)
        activeScreen = .login
    }

    private func endSession(completed: Bool) {
        stopTimer()

        let focused = totalSeconds - remainingSeconds
        if focused > 30 {
            sessionsCompleted += 1
            totalFocusSeconds += focused
            updateStreak()
            saveStats()
        }

        bgQueue.async { [weak self] in
            self?.blocker.unblockSites()
            self?.throttler.disableThrottling()
        }

        state = completed ? .complete : .idle
        clearSessionState()
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        // .common mode keeps the timer firing while user is scrolling/interacting
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        remainingSeconds = max(0, remainingSeconds - 1)
        lastTickDate = Date()

        if remainingSeconds % 5 == 0 {
            saveSessionState()
        }

        if remainingSeconds <= 0 {
            endSession(completed: true)
            activeScreen = .session
        }
    }

    // MARK: - Persistence

    private func saveSessionState() {
        let defaults = UserDefaults.standard
        defaults.set(state == .active || state == .paused, forKey: "sessionActive")
        defaults.set(remainingSeconds,  forKey: "remainingSeconds")
        defaults.set(totalSeconds,      forKey: "totalSeconds")
        defaults.set(screenName,        forKey: "sessionScreenName")
        defaults.set(state == .paused,  forKey: "sessionPaused")
        defaults.set(slowModeEnabled,   forKey: "sessionSlowMode")
        defaults.set(blockSitesEnabled, forKey: "sessionBlockSites")
        defaults.set(Date(),            forKey: "lastTickDate")
    }

    private func clearSessionState() {
        UserDefaults.standard.set(false, forKey: "sessionActive")
    }

    private func restoreSessionIfActive() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "sessionActive") else { return }

        remainingSeconds = defaults.integer(forKey: "remainingSeconds")
        totalSeconds     = defaults.integer(forKey: "totalSeconds")
        screenName       = defaults.string(forKey: "sessionScreenName") ?? "FocusUser"
        slowModeEnabled  = defaults.bool(forKey: "sessionSlowMode")
        blockSitesEnabled = defaults.bool(forKey: "sessionBlockSites")
        let wasPaused    = defaults.bool(forKey: "sessionPaused")

        if !wasPaused, let lastTick = defaults.object(forKey: "lastTickDate") as? Date {
            let elapsed = Int(Date().timeIntervalSince(lastTick))
            remainingSeconds = max(0, remainingSeconds - elapsed)
        }

        if remainingSeconds > 0 {
            state = wasPaused ? .paused : .active
            activeScreen = .session
            if !wasPaused { startTimer() }
        } else {
            clearSessionState()
        }
    }

    private func loadPreferences() {
        let defaults = UserDefaults.standard
        if let name = defaults.string(forKey: "screenName"), !name.isEmpty {
            screenName = name
        }
        sessionMinutes = defaults.integer(forKey: "sessionMinutes")
        if sessionMinutes < 5 { sessionMinutes = 25 }
        soundsEnabled      = defaults.object(forKey: "soundsEnabled") as? Bool ?? true
        customBlockedSites = defaults.stringArray(forKey: "customBlockedSites") ?? []
        loadStats()
    }

    func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(screenName,        forKey: "screenName")
        defaults.set(sessionMinutes,    forKey: "sessionMinutes")
        defaults.set(soundsEnabled,     forKey: "soundsEnabled")
        defaults.set(customBlockedSites, forKey: "customBlockedSites")
    }

    private func loadStats() {
        sessionsCompleted = UserDefaults.standard.integer(forKey: "statsSessionsCompleted")
        totalFocusSeconds = UserDefaults.standard.integer(forKey: "statsTotalFocusSeconds")
        focusStreak       = UserDefaults.standard.integer(forKey: "statsFocusStreak")
    }

    private func saveStats() {
        UserDefaults.standard.set(sessionsCompleted, forKey: "statsSessionsCompleted")
        UserDefaults.standard.set(totalFocusSeconds, forKey: "statsTotalFocusSeconds")
        UserDefaults.standard.set(focusStreak,       forKey: "statsFocusStreak")
    }

    private func updateStreak() {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())
        if let last = defaults.object(forKey: "statsLastCompletedDate") as? Date {
            let lastDay = Calendar.current.startOfDay(for: last)
            let diff = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if diff == 1 { focusStreak += 1 }
            else if diff > 1 { focusStreak = 1 }
            // diff == 0 means same day: keep current streak
        } else {
            focusStreak = 1
        }
        defaults.set(Date(), forKey: "statsLastCompletedDate")
    }

    func clearStats() {
        sessionsCompleted = 0
        totalFocusSeconds = 0
        focusStreak       = 0
        UserDefaults.standard.removeObject(forKey: "statsLastCompletedDate")
        saveStats()
    }

    // MARK: - Custom Sites

    func addCustomSite(_ domain: String) {
        var cleaned = domain.lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://",  with: "")
            .replacingOccurrences(of: "www.",     with: "")
        if let slash = cleaned.firstIndex(of: "/") {
            cleaned = String(cleaned[..<slash])
        }
        guard !cleaned.isEmpty, !customBlockedSites.contains(cleaned) else { return }
        customBlockedSites.append(cleaned)
        savePreferences()

        if state == .active || state == .paused {
            let sites = customBlockedSites
            bgQueue.async { [weak self] in self?.blocker.blockSites(customSites: sites) }
        }
    }

    func removeCustomSite(at index: Int) {
        customBlockedSites.remove(at: index)
        savePreferences()
        if state == .active || state == .paused {
            let sites = customBlockedSites
            bgQueue.async { [weak self] in self?.blocker.blockSites(customSites: sites) }
        }
    }

    // MARK: - Computed

    var timerString: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    var progressFraction: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    var statsAverageMinutes: Int {
        guard sessionsCompleted > 0 else { return 0 }
        return Int(Double(totalFocusSeconds) / Double(sessionsCompleted) / 60.0)
    }
}
