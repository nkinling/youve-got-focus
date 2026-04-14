# AOL Focus — You've Got Minutes! 🌐

> Dial-up era Pomodoro timer for macOS. Log in. Slow down. Get work done.

A native macOS menu bar app that:
- **Throttles your internet to 28.8kbps** using `pfctl` + `dummynet` (real OS-level throttling)
- **Blocks distraction sites** via `/etc/hosts` (reddit, twitter, youtube, etc.)
- **Counts down your focus session** Pomodoro-style
- **Looks and sounds like AOL in 1998** — Windows 95 UI, VT323 font, procedural modem screech

---

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+ (free from the App Store)
- Admin password (one-time setup only)

---

## Build Instructions

### 1. Install Xcode

Download from the Mac App Store or run:
```bash
xcode-select --install  # Command Line Tools only (smaller, may suffice)
```

For the full IDE, install **Xcode** from the Mac App Store.

### 2. Run One-Time Setup

```bash
cd "/Users/nick/Claude Code/AOLFocus"
chmod +x setup.sh
bash setup.sh
```

This creates `/etc/sudoers.d/aolfocus` which lets the app run `pfctl` and `dnctl` without password prompts. **You only need to do this once.**

### 3. Open in Xcode

```bash
open "/Users/nick/Claude Code/AOLFocus/AOLFocus.xcodeproj"
```

Or double-click `AOLFocus.xcodeproj` in Finder.

### 4. Build and Run

1. Select the **AOLFocus** scheme at the top
2. Press **⌘B** to build (first build may take 30–60 seconds)
3. Press **⌘R** to run

The AOL globe icon (🌐) will appear in your menu bar.

### 5. First Launch — Gatekeeper

If you distribute the built `.app` to another Mac:
```bash
xattr -d com.apple.quarantine AOLFocus.app
```
Or right-click the app → Open → Open (bypasses Gatekeeper for unsigned apps).

---

## How It Works

### Network Throttling (Real Dial-Up Speed)

When you start a session with Slow Mode enabled:

```bash
# Configures dummynet pipe at 28.8kbps with 200ms latency
sudo dnctl pipe 1 config bw 28.8Kbit/s delay 200

# Applies to ALL inbound and outbound traffic
printf 'dummynet in all pipe 1\ndummynet out all pipe 1\n' | sudo pfctl -f -
sudo pfctl -E
```

This is **system-wide** — every app (browser, Slack, email) gets throttled.

When your session ends:
```bash
sudo dnctl -q flush
sudo pfctl -d
```

### Site Blocking (/etc/hosts)

When "Block sites" is enabled, adds entries like:
```
127.0.0.1   reddit.com    # AOL-FOCUS
127.0.0.1   www.reddit.com  # AOL-FOCUS
```

All entries are tagged with `# AOL-FOCUS` and are cleanly removed when your session ends.

### Sound Effects

Pure procedural synthesis via `AVAudioEngine` — no audio files needed:
- **Dial-up screech** on login (DTMF tones → carrier detection → handshake burst)
- **Connect chime** when session starts
- **Goodbye chime** when session ends
- **Urgent beep** at 5 minutes and 1 minute remaining

---

## File Structure

```
AOLFocus/
├── AOLFocusApp.swift        — App entry, menu bar icon
├── AppDelegate.swift        — NSStatusItem + NSPopover
├── FocusSession.swift       — Session state, timer, persistence
├── NetworkThrottler.swift   — pfctl/dnctl bandwidth throttling
├── SiteBlocker.swift        — /etc/hosts site blocking
├── SoundEngine.swift        — Procedural modem sounds (AVAudioEngine)
└── Views/
    ├── PopoverView.swift    — Root router + Win95 design system
    ├── LoginView.swift      — AOL login screen + connecting animation
    ├── SessionView.swift    — Active session timer + buddy list
    ├── StatsView.swift      — Session history stats
    └── SitesView.swift      — Custom blocked sites manager
```

---

## Uninstall

1. Quit the app (right-click menu bar icon → Quit)
2. Remove sudoers entry: `sudo rm /etc/sudoers.d/aolfocus`
3. Delete the app

---

## Troubleshooting

**"Operation not permitted" when throttling**
→ Run `setup.sh` first to configure passwordless sudo.

**Throttling doesn't seem to work**
→ Check with: `sudo pfctl -sd` — you should see dummynet rules.
→ Some apps use QUIC/HTTP3 which may bypass pfctl. Force TCP in Chrome: disable QUIC in `chrome://flags`.

**Sites not blocked**
→ DNS cache may be stale. Run: `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder`

**App shows generic icon in menu bar**
→ This is expected if running unsigned. The 🌐 emoji icon renders via NSStatusItem.

**Build fails: "Missing entitlement"**
→ Make sure `AOLFocus.entitlements` has `com.apple.security.app-sandbox = NO`. Check Build Settings → Code Signing Entitlements.

---

*AOL Focus v5.0 — 28.8 kbps of pure productivity.*
*You've got minutes. Use them.*
