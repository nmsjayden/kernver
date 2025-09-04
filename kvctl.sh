#!/bin/bash
# kernverctl - Interactive TPM kernver controller for ChromeOS
# Blocks or restores kernver bump
# Pipeable: curl ... | bash

# Re-exec as root if not running as root
if [ "$EUID" -ne 0 ]; then
  exec sudo bash "$0" "$@"
fi

STUB_DIR="/usr/local/tpm_stub"
STUB_FILE="$STUB_DIR/tpm_managerd"
TARGET="/usr/sbin/tpm_managerd"
BACKUP="$STUB_DIR/tpm_managerd.backup"
INIT_SCRIPT="/etc/init/stub-tpm.conf"

mkdir -p "$STUB_DIR"

echo "TPM kernver Control Script"
echo "=========================="
echo "1) Block kernver updates (install stub)"
echo "2) Restore original tpm_managerd (undo)"
read -p "Choose an option (1 or 2): " CHOICE

set -e
set -o pipefail
set -u

case "$CHOICE" in
  1)
    echo "[*] Installing TPM stub to block kernver updates..."
    mount -o remount,rw /

    if [ -f "$BACKUP" ]; then
      echo "[!] Backup already exists at $BACKUP. Not overwriting."
      echo "[*] Skipping backup creation."
    else
      echo "[*] Backing up original tpm_managerd to $BACKUP"
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

    echo "[+] Stub installed. Kernver updates are now blocked."
    ;;

  2)
    echo "[*] Restoring original tpm_managerd..."
    if [ -f "$BACKUP" ]; then
      mount -o remount,rw /
      cp "$BACKUP" "$TARGET"
      rm -f "$INIT_SCRIPT"
      echo "[+] Original tpm_managerd restored. Stub removed."
    else
      echo "[!] No backup found at $BACKUP. Cannot restore."
    fi
    ;;

  *)
    echo "[!] Invalid option. Exiting."
    exit 1
    ;;
esac
