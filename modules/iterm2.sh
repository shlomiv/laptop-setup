#!/bin/bash
source "$(dirname "$0")/_common.sh"

info "Setting up iTerm2..."

PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
PROFILE=":New Bookmarks:0"

# Font: MesloLGS Nerd Font (for powerlevel10k)
/usr/libexec/PlistBuddy -c "Set '${PROFILE}:Normal Font' 'MesloLGS-NF-Regular 13'" "$PLIST"

# Scrollback
/usr/libexec/PlistBuddy -c "Set '${PROFILE}:Scrollback Lines' 1000" "$PLIST"

# Keyboard Map — hex code keybindings for terminal nav
# Action 10 = Send Escape Sequence, Action 11 = Send Hex Code
set_key() {
    local key="$1" action="$2" text="$3"
    local path="${PROFILE}:Keyboard Map:${key}"
    /usr/libexec/PlistBuddy -c "Delete '${path}'" "$PLIST" 2>/dev/null
    /usr/libexec/PlistBuddy -c "Add '${path}' dict" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add '${path}:Action' integer ${action}" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add '${path}:Text' string ${text}" "$PLIST"
}

set_key "0xf702-0x280000" 10 "b"          # Option+Left → Esc+b (word back)
set_key "0xf703-0x280000" 10 "f"          # Option+Right → Esc+f (word forward)
set_key "0xf728-0x80000"  10 "d"          # Option+Delete → Esc+d (del word fwd)
set_key "0xf728-0x0"      11 "0x4"        # Delete fwd → Ctrl+D
set_key "0xf702-0x300000" 11 "0x1"        # Cmd+Left → Ctrl+A (line start)
set_key "0xf703-0x300000" 11 "0x5"        # Cmd+Right → Ctrl+E (line end)
set_key "0x7f-0x80000"    11 "0x1b 0x7f"  # Option+Backspace → Esc+Del (del word back)
set_key "0x7f-0x100000"   11 "0x15"       # Cmd+Backspace → Ctrl+U (kill line)

# Global Key Map — Shift+Enter → Send Hex 0x0a (newline for Claude Code in tmux)
/usr/libexec/PlistBuddy -c "Delete ':GlobalKeyMap:0xd-0x20000-0x24'" "$PLIST" 2>/dev/null
/usr/libexec/PlistBuddy -c "Add ':GlobalKeyMap:0xd-0x20000-0x24' dict" "$PLIST"
/usr/libexec/PlistBuddy -c "Add ':GlobalKeyMap:0xd-0x20000-0x24:Version' integer 2" "$PLIST"
/usr/libexec/PlistBuddy -c "Add ':GlobalKeyMap:0xd-0x20000-0x24:Apply Mode' integer 0" "$PLIST"
/usr/libexec/PlistBuddy -c "Add ':GlobalKeyMap:0xd-0x20000-0x24:Action' integer 11" "$PLIST"
/usr/libexec/PlistBuddy -c "Add ':GlobalKeyMap:0xd-0x20000-0x24:Text' string 0x0a" "$PLIST"
/usr/libexec/PlistBuddy -c "Add ':GlobalKeyMap:0xd-0x20000-0x24:Escaping' integer 2" "$PLIST"

ok "iTerm2: Font=MesloLGS-NF 13, hex key mappings, Shift+Enter=newline"
