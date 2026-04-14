#!/bin/bash
# AOL Focus — One-Time Setup
# Grants passwordless sudo for pfctl, dnctl, and /etc/hosts editing.
# Run this ONCE from Terminal: bash setup.sh

set -e

CURRENT_USER="$(whoami)"
SUDOERS_FILE="/etc/sudoers.d/aolfocus"
TMP_FILE="/tmp/aolfocus_sudoers_$$"

echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║     AOL Focus — Setup Wizard v5.0         ║"
echo "║     Dial-Up Era Productivity               ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
echo "This will create $SUDOERS_FILE"
echo "so AOL Focus can throttle/unthrottle without a password prompt."
echo ""
echo "You will need your admin password."
echo ""

# Build the sudoers content in a temp file first (no heredoc quoting issues)
cat > "$TMP_FILE" << EOF
# AOL Focus — Network throttling permissions
# To remove: sudo rm $SUDOERS_FILE
$CURRENT_USER ALL=(ALL) NOPASSWD: /sbin/pfctl
$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/sbin/dnctl
$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/sbin/dscacheutil
$CURRENT_USER ALL=(ALL) NOPASSWD: /bin/kill
$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/bin/tee -a /etc/hosts
$CURRENT_USER ALL=(ALL) NOPASSWD: /bin/cp
$CURRENT_USER ALL=(ALL) NOPASSWD: /bin/cat /etc/hosts
$CURRENT_USER ALL=(ALL) NOPASSWD: /bin/rm
EOF

# Validate syntax before installing
/usr/sbin/visudo -c -f "$TMP_FILE" 2>&1 && echo "✓ Sudoers syntax valid" || {
    echo "✗ Sudoers syntax error — aborting"
    rm -f "$TMP_FILE"
    exit 1
}

# Install with sudo
sudo cp "$TMP_FILE" "$SUDOERS_FILE"
sudo chmod 440 "$SUDOERS_FILE"
rm -f "$TMP_FILE"

echo "✓ Sudoers file installed at $SUDOERS_FILE"
echo ""

# Verify the key commands now work without password
echo "Verifying passwordless sudo..."
sudo -n /usr/sbin/dnctl list > /dev/null 2>&1 && echo "✓ dnctl: OK" || echo "⚠ dnctl: may still prompt (check sudoers)"
sudo -n /sbin/pfctl -s info > /dev/null 2>&1 && echo "✓ pfctl: OK" || echo "⚠ pfctl: may still prompt (check sudoers)"

# Quick throttle smoke test
echo ""
echo "Running 3-second throttle test at 1 Mbit/s..."
sudo /usr/sbin/dnctl pipe 1 config bw 1Mbit/s delay 50 2>/dev/null || { echo "⚠ dnctl failed"; exit 1; }
printf 'dummynet in all pipe 1\ndummynet out all pipe 1\n' | sudo /sbin/pfctl -f - 2>/dev/null || true
sudo /sbin/pfctl -E 2>/dev/null || true
echo "✓ Throttle active (your internet just got slower for 3 seconds...)"
sleep 3
sudo /usr/sbin/dnctl -q flush 2>/dev/null || true
sudo /sbin/pfctl -d 2>/dev/null || true
echo "✓ Throttle disabled — internet restored"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  ✓ Setup complete! Open Xcode and build.     ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "To uninstall later: sudo rm $SUDOERS_FILE"
echo ""
