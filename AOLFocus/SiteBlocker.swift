import Foundation

/// Manages /etc/hosts to block distraction sites at the OS level.
/// All blocked entries are marked with # AOL-FOCUS for clean removal.
/// Uses single-script execution to minimize process spawn overhead.
class SiteBlocker {

    private let marker = "# AOL-FOCUS"
    private let hostsPath = "/etc/hosts"

    private let defaultBlockedSites = [
        "reddit.com", "twitter.com", "x.com", "youtube.com",
        "instagram.com", "facebook.com", "tiktok.com", "twitch.tv",
        "news.ycombinator.com", "linkedin.com"
    ]

    func blockSites(customSites: [String] = []) {
        let allSites = Array(Set(defaultBlockedSites + customSites)).sorted()

        // Build the block to append — all in one string
        var lines: [String] = ["", "# === AOL FOCUS BLOCKED SITES ==="]
        for site in allSites {
            lines.append("127.0.0.1\t\(site)\t\(marker)")
            lines.append("127.0.0.1\twww.\(site)\t\(marker)")
            lines.append("::1\t\(site)\t\(marker)")
            lines.append("::1\twww.\(site)\t\(marker)")
        }
        lines.append("# === END AOL FOCUS ===")
        let block = lines.joined(separator: "\n")

        // One shell script: remove old entries, append new ones, flush DNS
        let script = """
        set -e
        HOSTS="/etc/hosts"
        TMP=$(mktemp /tmp/aolfocus_hosts_XXXXXX)

        # Strip existing AOL Focus entries
        sudo grep -v '# AOL-FOCUS' "$HOSTS" | \
            grep -v '# === AOL FOCUS' | \
            grep -v '# === END AOL FOCUS' | \
            sed -e 's/[[:space:]]*$//' | \
            awk 'NF || prev_nf {print; prev_nf=NF}' > "$TMP" || true

        # Append new block
        printf '%s\n' \(shellEscape(block)) >> "$TMP"

        # Swap in atomically
        sudo cp "$TMP" "$HOSTS"
        rm -f "$TMP"

        # Flush DNS (ignore errors — not fatal)
        sudo /usr/sbin/dscacheutil -flushcache 2>/dev/null || true
        sudo killall -HUP mDNSResponder 2>/dev/null || true
        """

        runScript(script, timeout: 15)
    }

    func unblockSites() {
        let script = """
        set -e
        HOSTS="/etc/hosts"
        TMP=$(mktemp /tmp/aolfocus_hosts_XXXXXX)

        # Strip AOL Focus entries
        sudo grep -v '# AOL-FOCUS' "$HOSTS" | \
            grep -v '# === AOL FOCUS' | \
            grep -v '# === END AOL FOCUS' | \
            sed -e 's/[[:space:]]*$//' | \
            awk 'NF || prev_nf {print; prev_nf=NF}' > "$TMP" || true

        sudo cp "$TMP" "$HOSTS"
        rm -f "$TMP"

        sudo /usr/sbin/dscacheutil -flushcache 2>/dev/null || true
        sudo killall -HUP mDNSResponder 2>/dev/null || true
        """

        runScript(script, timeout: 15)
    }

    // MARK: - Shell helpers

    /// Run a multi-line bash script in a single Process with a hard timeout.
    @discardableResult
    private func runScript(_ script: String, timeout: TimeInterval = 10) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do { try process.run() } catch { return -1 }

        // Hard timeout — never hang the bg queue indefinitely
        let deadline = DispatchTime.now() + timeout
        var timedOut = false
        DispatchQueue.global().asyncAfter(deadline: deadline) {
            if process.isRunning {
                timedOut = true
                process.terminate()
            }
        }

        process.waitUntilExit()
        return timedOut ? -2 : process.terminationStatus
    }

    private func shellEscape(_ s: String) -> String {
        // $'...' ANSI-C quoting handles newlines and special chars safely
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'",  with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "$'\(escaped)'"
    }
}
