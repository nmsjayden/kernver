#!/bin/bash
# kernverctl - Pipeable TPM kernver controller for ChromeOS
# VT2 interactive version (no remount calls)

if [ "$EUID" -ne 0 ]; then
  echo "[*] Re-executing as root..."
  exec sudo bash "$0"
fi

STUB_DIR="/usr/local/tpm_stub"
STUB_FILE="$STUB_DIR/tpm_managerd"
TARGET="/usr/sbin/tpm_managerd"
BACKUP="$STUB_DIR/tpm_managerd.backup"
INIT_SCRIPT="/etc/init/stub-tpm.conf"

mkdir -p "$STUB_DIR"

tty_in="/dev/tty"
tty_out="/dev/tty"

echo "TPM kernver Control Script" > "$tty_out"
echo "==========================" > "$tty_out"
echo "1) Block kernver updates (install stub)" > "$tty_out"
echo "2) Restore original tpm_managerd (undo)" > "$tty_out"
read -p "Choose an option (1 or 2): " CHOICE < "$tty_in"

set -euo pipefail

case "$CHOICE" in
  1)
    echo "[*] Installing TPM stub..." > "$tty_out"

    if [ -f "$BACKUP" ]; then
      echo "[!] Backup exists. Skipping..." > "$tty_out"
    else
      echo "[*] Backing up original tpm_managerd..." > "$tty_out"
      cp "$TARGET" "$BACKUP"
    fi

    echo -e '#!/bin/sh\nexit 0' > "$STUB_FILE"
    chmod +x "$STUB_FILE"
    cp "$STUB_FILE" "$TARGET"

    cat <<EOF > "$INIT_SCRIPT"
description "TPM managerd stub auto-replacer"

start on started system-services

script
  cp "$STUB_FILE" "$TARGET"
  chmod +x "$TARGET"
end script
EOF

    echo "[+] Stub installed." > "$tty_out"
    ;;

  2)
    echo "[*] Restoring original tpm_managerd..." > "$tty_out"
    if [ -f "$BACKUP" ]; then
      cp "$BACKUP" "$TARGET"
      rm -f "$INIT_SCRIPT"
      echo "[+] Original restored." > "$tty_out"
    else
      echo "[!] No backup found." > "$tty_out"
    fi
    ;;

  *)
    echo "[!] Invalid option. Exiting." > "$tty_out"
    exit 1
    ;;
esac
