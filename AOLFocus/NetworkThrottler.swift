import Foundation

/// Controls system-level network throttling via pfctl + dnctl (dummynet).
/// Requires the one-time setup.sh to have been run (adds NOPASSWD sudoers entry).
/// Uses single-script execution to minimize process spawn overhead.
class NetworkThrottler {

    private let kbps = 29  // ~28.8 kbps authentic dial-up

    func enableThrottling() {
        let script = """
        sudo /usr/sbin/dnctl pipe 1 config bw \(kbps)Kbit/s delay 200
        printf 'dummynet in all pipe 1\ndummynet out all pipe 1\n' | sudo /sbin/pfctl -f -
        sudo /sbin/pfctl -E 2>/dev/null || true
        """
        runScript(script, timeout: 10)
    }

    func disableThrottling() {
        let script = """
        sudo /usr/sbin/dnctl -q flush 2>/dev/null || true
        sudo /sbin/pfctl -f /etc/pf.conf 2>/dev/null || true
        sudo /sbin/pfctl -d 2>/dev/null || true
        """
        runScript(script, timeout: 10)
    }

    func isThrottlingActive() -> Bool {
        let result = runCapture("sudo /usr/sbin/dnctl list 2>/dev/null", timeout: 5)
        return result.contains("pipe 1")
    }

    // MARK: - Shell helpers

    @discardableResult
    private func runScript(_ script: String, timeout: TimeInterval) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do { try process.run() } catch { return -1 }

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

    private func runCapture(_ command: String, timeout: TimeInterval) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do { try process.run() } catch { return "" }

        let deadline = DispatchTime.now() + timeout
        DispatchQueue.global().asyncAfter(deadline: deadline) {
            if process.isRunning { process.terminate() }
        }

        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
