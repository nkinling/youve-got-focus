import Foundation

/// Controls system-level network throttling via pfctl + dnctl (dummynet).
///
/// First-run: uses osascript to install a sudoers rule granting passwordless
/// access to dnctl and pfctl for the current user. After that one-time setup
/// every subsequent call uses `sudo -n` silently — no password dialog ever again.
///
/// Rules are appended to /etc/pf.conf at enable time and cleaned up by
/// restoring /etc/pf.conf on disable, so existing firewall anchors
/// (VPN, content filters, etc.) are never disturbed.
class NetworkThrottler {

    private let kbps    = 56    // 56 kbps — matches the "56 kbps" UI label
    private let delayMs = 150   // ~150 ms latency for authentic dial-up feel

    // MARK: - Public API

    func enableThrottling() {
        ensureSudoersEntry()
        runSudo("""
            /usr/sbin/dnctl pipe 1 config bw \(kbps)Kbit/s delay \(delayMs) || true
            (cat /etc/pf.conf; echo "dummynet out all pipe 1") | /sbin/pfctl -f - 2>/dev/null || true
            /sbin/pfctl -E 2>/dev/null || true
        """)
    }

    func disableThrottling() {
        runSudo("""
            /usr/sbin/dnctl pipe 1 delete 2>/dev/null || true
            /sbin/pfctl -f /etc/pf.conf 2>/dev/null || true
        """)
    }

    // MARK: - One-time sudoers setup

    /// Checks whether passwordless sudo already works for dnctl.
    /// If not, runs a one-time osascript prompt to install /etc/sudoers.d/aolfocus.
    private func ensureSudoersEntry() {
        // -n = non-interactive: exits immediately with error if a password would be needed
        let check = runCapture("sudo -n /usr/sbin/dnctl list 2>&1", timeout: 3)
        let needsSetup = check.lowercased().contains("password") ||
                         check.lowercased().contains("sudo:")

        guard needsSetup else { return }   // already set up — nothing to do

        let user = NSUserName()
        let sudoersLine = "\(user) ALL=(root) NOPASSWD: /usr/sbin/dnctl, /sbin/pfctl"
        let sudoersFile = "/etc/sudoers.d/aolfocus"

        // Install the sudoers file via a single osascript prompt.
        // This is the ONLY time the user ever sees a password dialog.
        let installScript = """
            #!/bin/bash
            echo '\(sudoersLine)' > \(sudoersFile)
            chmod 440 \(sudoersFile)
        """
        runPrivileged(
            script: installScript,
            prompt: "AOL Focus needs one-time permission to enable dial-up slow mode."
        )
    }

    // MARK: - Shell helpers

    /// Runs a bash script with `sudo -n` (non-interactive, no password prompt).
    /// Works silently after the one-time sudoers entry is in place.
    @discardableResult
    private func runSudo(_ script: String) -> Int32 {
        let tmp = makeTempScript("#!/bin/bash\n" + script)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-c", "sudo -n \(tmp.path) 2>/dev/null"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError  = FileHandle.nullDevice
        do { try p.run() } catch { return -1 }
        p.waitUntilExit()
        return p.terminationStatus
    }

    /// Runs a bash script via osascript with a custom prompt message.
    /// Use only for the one-time sudoers setup.
    private func runPrivileged(script: String, prompt: String) {
        let tmp = makeTempScript(script)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let safePath   = tmp.path.replacingOccurrences(of: "\"", with: "\\\"")
        let safePrompt = prompt.replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = """
            do shell script "\(safePath)" \
            with prompt "\(safePrompt)" \
            with administrator privileges
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", appleScript]
        p.standardOutput = FileHandle.nullDevice
        p.standardError  = FileHandle.nullDevice
        do { try p.run() } catch { return }
        p.waitUntilExit()
    }

    private func makeTempScript(_ content: String) -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("aolfocus_\(Int.random(in: 10000...99999)).sh")
        try? content.write(to: url, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    private func runCapture(_ command: String, timeout: TimeInterval) -> String {
        let p    = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments     = ["-c", command]
        p.standardOutput = pipe
        p.standardError  = FileHandle.nullDevice
        do { try p.run() } catch { return "" }
        let deadline = DispatchTime.now() + timeout
        DispatchQueue.global().asyncAfter(deadline: deadline) {
            if p.isRunning { p.terminate() }
        }
        p.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                      encoding: .utf8) ?? ""
    }
}
