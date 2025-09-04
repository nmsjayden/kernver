#!/bin/bash
# Interactive TPM kernver controller for ChromeOS
# Blocks or restores kernver bump

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

case "$CHOICE" in
  1)
    echo "[*] Installing TPM stub to block kernver updates..."

    sudo mount -o remount,rw /

    # Backup original if not already backed up
    if [ -f "$BACKUP" ]; then
      echo "[!] Backup already exists at $BACKUP. Not overwriting."
      echo "[*] Skipping backup creation."
    else
      echo "[*] Backing up original tpm_managerd to $BACKUP"
      sudo cp "$TARGET" "$BACKUP"
    fi

    # Create stub
    echo -e '#!/bin/sh\nexit 0' | sudo tee "$STUB_FILE" >/dev/null
    sudo chmod +x "$STUB_FILE"

    # Replace system binary
    sudo cp "$STUB_FILE" "$TARGET"

    # Add boot-time patcher
    cat <<EOF | sudo tee "$INIT_SCRIPT" >/dev/null
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
      sudo mount -o remount,rw /
      sudo cp "$BACKUP" "$TARGET"
      sudo rm -f "$INIT_SCRIPT"
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
