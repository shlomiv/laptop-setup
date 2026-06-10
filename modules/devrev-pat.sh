#!/bin/bash
source "$(dirname "$0")/_common.sh"

info "Setting up DevRev PAT..."

SERVICE="devrev-pat"
ACCOUNT="devrev-cli"

# Check if already stored
existing=$(security find-generic-password -s "$SERVICE" -a "$ACCOUNT" -w 2>/dev/null)
if [[ -n "$existing" ]]; then
    ok "DevRev PAT already in Keychain"
else
    printf "Enter your DevRev PAT: "
    read -rs pat
    echo

    if [[ -z "$pat" ]]; then
        err "No PAT provided, skipping"
        exit 1
    fi

    security add-generic-password -s "$SERVICE" -a "$ACCOUNT" -w "$pat"
    ok "DevRev PAT stored in Keychain (service=$SERVICE, account=$ACCOUNT)"
fi

info "To use in scripts: security find-generic-password -s '$SERVICE' -a '$ACCOUNT' -w"
