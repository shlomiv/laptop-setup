#!/bin/bash
# Enhanced statusline combining custom features + daniel3303/ClaudeCodeStatusLine inspiration
# Backup: ~/.claude/statusline-command.sh.backup

set -f  # disable globbing

# Read JSON input
input=$(cat)

# Set GitHub token for gh CLI
export GH_TOKEN=$(security find-generic-password -s "github" -a "claude-code-2" -w 2>/dev/null)

# ANSI colors
blue='\033[38;2;0;153;255m'
orange='\033[38;2;255;176;85m'
green='\033[38;2;0;160;0m'
cyan='\033[38;2;46;149;153m'
red='\033[38;2;255;85;85m'
yellow='\033[38;2;230;200;0m'
magenta='\033[35m'
branch_blue='\033[38;2;170;179;240m'
dim='\033[2m'
reset='\033[0m'

# Helper: format tokens (e.g., 50k, 1.5m)
format_tokens() {
    local num=$1
    if [ "$num" -ge 1000000 ]; then
        awk "BEGIN {v=sprintf(\"%.1f\",$num/1000000)+0; if(v==int(v)) printf \"%dm\",v; else printf \"%.1fm\",v}"
    elif [ "$num" -ge 1000 ]; then
        awk "BEGIN {printf \"%.0fk\", $num / 1000}"
    else
        printf "%d" "$num"
    fi
}

# Helper: return color based on usage percentage
usage_color() {
    local pct=$1
    if [ "$pct" -ge 90 ]; then echo -n "$red"
    elif [ "$pct" -ge 70 ]; then echo -n "$orange"
    elif [ "$pct" -ge 50 ]; then echo -n "$yellow"
    else echo -n "$green"
    fi
}

# Helper: get terminal width using parent process walking
get_terminal_width() {
    local current_pid=$$
    local attempts=0
    local max_attempts=8

    while [[ $attempts -lt $max_attempts ]]; do
        local parent_pid=$(ps -o ppid= -p "$current_pid" 2>/dev/null | tr -d ' ')
        [[ -z "$parent_pid" || "$parent_pid" == "1" ]] && break

        local tty=$(ps -o tty= -p "$parent_pid" 2>/dev/null | tr -d ' ')
        if [[ -n "$tty" && "$tty" != "?" && "$tty" != "??" ]]; then
            local width=$(stty size < /dev/"$tty" 2>/dev/null | cut -d' ' -f2)
            if [[ -n "$width" && "$width" -gt 0 ]]; then
                echo "$width"
                return 0
            fi
        fi

        current_pid=$parent_pid
        attempts=$((attempts + 1))
    done

    local width=$(tput cols 2>/dev/null)
    if [[ -n "$width" && "$width" -gt 0 ]]; then
        echo "$width"
        return 0
    fi

    echo "180"
}

# Helper: strip ANSI codes (including RGB colors)
strip_ansi() {
    # Remove all ANSI escape sequences
    echo "$1" | perl -pe 's/\e\[[0-9;]*m//g'
}

# Extract current directory from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')

# Get git info if in a git repo
git_info=""
git_dirty_mark=""
if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null || echo "detached")

    # Check if repo is dirty
    if ! git -C "$cwd" diff --quiet 2>/dev/null || ! git -C "$cwd" diff --cached --quiet 2>/dev/null; then
        git_info=$(printf "${branch_blue}%s${red}⚡${reset} " "$branch")
        git_dirty_mark="⚡"

        # Get file change stats (+additions -deletions)
        git_stat=$(git -C "$cwd" diff --numstat 2>/dev/null | awk '{a+=$1; d+=$2} END {if (a+d>0) printf "+%d -%d", a, d}')
        if [[ -n "$git_stat" ]]; then
            git_info=$(printf "${branch_blue}%s${red}⚡${reset}${dim}(${reset}${green}%s${reset} ${red}%s${reset}${dim})${reset} " \
                "$branch" "${git_stat%% *}" "${git_stat##* }")
        fi
    else
        git_info=$(printf "${branch_blue}%s ${green}✓${reset} " "$branch")
    fi
fi

# Get PR number if current branch has one (cached per branch, 5min TTL, stale on failure)
pr_info=""
pr_text=""
if [[ -n "$cwd" && -n "$branch" ]] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    pr_cache="/tmp/claude-pr-cache.${branch//\//_}"
    pr_number=""
    pr_url=""
    needs_pr_check=true

    if [[ -f "$pr_cache" ]]; then
        cache_mtime=$(stat -f %m "$pr_cache" 2>/dev/null || stat -c %Y "$pr_cache" 2>/dev/null)
        now=$(date +%s)
        if [[ $(( now - cache_mtime )) -lt 300 ]]; then  # 5 minutes
            needs_pr_check=false
            pr_number=$(sed -n '1p' "$pr_cache")
            pr_url=$(sed -n '2p' "$pr_cache")
        fi
    fi

    if $needs_pr_check; then
        pr_json=$(cd "$cwd" && gh pr view --json number,url 2>&1)
        if [[ $? -eq 0 && -n "$pr_json" ]]; then
            pr_number=$(echo "$pr_json" | jq -r '.number // empty' 2>/dev/null)
            pr_url=$(echo "$pr_json" | jq -r '.url // empty' 2>/dev/null)
            printf '%s\n%s\n' "$pr_number" "$pr_url" > "$pr_cache"
        elif [[ -f "$pr_cache" ]]; then
            # gh failed (rate limit, network) — keep stale cache
            pr_number=$(sed -n '1p' "$pr_cache")
            pr_url=$(sed -n '2p' "$pr_cache")
        fi
    fi

    if [[ -n "$pr_number" && -n "$pr_url" ]]; then
        pr_info=$(printf '\e]8;;%s\e\\%b#%s%b\e]8;;\e\\ ' "$pr_url" "$cyan" "$pr_number" "$reset")
        pr_text=" #${pr_number}"
    fi
fi

# Extract model info
model=$(echo "$input" | jq -r '.model.display_name // "unknown"')
model_short="$model"  # Use full display name (e.g., "Sonnet 4.5")

# Get effort level from settings
effort=$(jq -r '.effortLevel // empty' /Users/shlomi/.claude/settings.json 2>/dev/null)
effort_info=""
if [[ -n "$effort" ]]; then
    effort_info=" ${dim}(${reset}${effort}${dim})${reset}"
fi

# Calculate context usage
size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
current=$(( input_tokens + cache_create + cache_read ))

used_tokens=$(format_tokens $current)
total_tokens=$(format_tokens $size)

if [ "$size" -gt 0 ]; then
    pct_used=$(( current * 100 / size ))
else
    pct_used=0
fi

context_color=$(usage_color $pct_used)

# Extract session info
session_duration=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
if [[ $session_duration -gt 0 ]]; then
    session_mins=$((session_duration / 60000))
    if [[ $session_mins -ge 60 ]]; then
        session_hours=$((session_mins / 60))
        session_mins=$((session_mins % 60))
        session_display="${session_hours}h${session_mins}m"
    else
        session_display="${session_mins}m"
    fi
else
    session_display="0m"
fi


# Get rate limits from JSON (if available)
five_hour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
seven_day_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null)

rate_limits_info=""
if [[ -n "$five_hour_pct" ]]; then
    five_hour_pct_int=$(printf '%.0f' "$five_hour_pct" 2>/dev/null)
    five_hour_color=$(usage_color $five_hour_pct_int)
    rate_limits_info+=" ${dim}|${reset} 5h:${five_hour_color}${five_hour_pct_int}%${reset}"
fi
if [[ -n "$seven_day_pct" ]]; then
    seven_day_pct_int=$(printf '%.0f' "$seven_day_pct" 2>/dev/null)
    seven_day_color=$(usage_color $seven_day_pct_int)
    rate_limits_info+=" 7d:${seven_day_color}${seven_day_pct_int}%${reset}"
fi

# Check for Claude Code updates (cache for 1 hour)
version_info=""
version_cache="/tmp/claude-version-check.cache"
current_version=$(echo "$input" | jq -r '.version // empty')
[[ -z "$current_version" ]] && current_version=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [[ -n "$current_version" ]]; then
    update_status=""
    needs_check=true
    if [[ -f "$version_cache" ]]; then
        cache_mtime=$(stat -f %m "$version_cache" 2>/dev/null || stat -c %Y "$version_cache" 2>/dev/null)
        now=$(date +%s)
        cache_age=$(( now - cache_mtime ))
        if [[ $cache_age -lt 3600 ]]; then  # 1 hour
            needs_check=false
            cached_result=$(cat "$version_cache" 2>/dev/null)
            update_status="$cached_result"
        fi
    fi

    if $needs_check; then
        latest_version=$(claude update --check 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tail -1)
        [[ -z "$latest_version" ]] && latest_version=$(npm view @anthropic-ai/claude-code version 2>/dev/null)
        if [[ -n "$latest_version" ]] && [[ "$latest_version" != "$current_version" ]]; then
            echo "update_available:$latest_version" > "$version_cache"
            update_status="update_available:$latest_version"
        else
            echo "up_to_date" > "$version_cache"
            update_status="up_to_date"
        fi
    fi

    # If cache says update available but we already have that version, treat as up-to-date
    if [[ "$update_status" == update_available:* ]]; then
        latest=${update_status#update_available:}
        if [[ "$latest" == "$current_version" ]]; then
            update_status="up_to_date"
            echo "up_to_date" > "$version_cache"
        fi
    fi

    if [[ "$update_status" == up_to_date ]]; then
        version_info=" ${dim}|${reset} v${current_version} ${green}✓${reset}"
    elif [[ "$update_status" == update_available* ]]; then
        latest=${update_status#update_available:}
        version_info=" ${dim}|${reset} v${current_version} ${yellow}⬆ ${latest}${reset}"
    else
        version_info=" ${dim}|${reset} v${current_version}"
    fi
fi

# Build left side output
output="${git_info}${dim}|${reset} "
# Only include PR info segment if there's a PR
[[ -n "$pr_info" ]] && output+="${pr_info}${dim}|${reset} "
output+="🏷  ${magenta}${model_short}${reset}${effort_info} ${dim}|${reset} "
output+="📊 ${context_color}${used_tokens}/${total_tokens}${reset} ${dim}(${reset}${context_color}${pct_used}%${reset}${dim})${reset} ${dim}|${reset} "
output+="⏱ ${magenta}${session_display}${reset}${rate_limits_info}${version_info}"

# Calculate visible text lengths (manually count the actual characters)
# Git: branch⚡(+X -Y) or branch ✓
branch_len=${#branch}
git_visible_len=$((branch_len + 1))  # branch + space
[[ -z "$git_dirty_mark" ]] && git_visible_len=$((git_visible_len + 2))  # ✓ + space
[[ -n "$git_dirty_mark" ]] && git_visible_len=$((git_visible_len + 1))  # ⚡
if [[ -n "$git_stat" ]]; then
    stat_len=$(echo "$git_stat" | wc -c)
    git_visible_len=$((git_visible_len + stat_len + 2))  # ()
fi

# PR: #29
pr_len=0
pr_separator_len=0
if [[ -n "$pr_number" ]]; then
    pr_len=$((${#pr_number} + 2))  # #29 with space
    pr_separator_len=3  # " | " separator
fi

# Model info: 🏷  sonnet | 📊 73k/200k (36%) | ⏱ 12h14m
# Emojis are typically 2 chars wide in terminal
effort_visible_len=0
[[ -n "$effort" ]] && effort_visible_len=$((${#effort} + 3))  # " (High)" etc.
model_info_len=$((${#model_short} + effort_visible_len + ${#used_tokens} + ${#total_tokens} + ${#pct_used} + ${#session_display} + 3 + 7 + 12))  # includes /, (), %, spaces, emoji widths
[[ -n "$rate_limits_info" ]] && model_info_len=$((model_info_len + 20))  # approximate for rate limits
[[ -n "$version_info" ]] && model_info_len=$((model_info_len + ${#current_version} + 4))  # v1.2.3 ✓/⬆

left_length=$((git_visible_len + 5 + pr_len + pr_separator_len + model_info_len + 6))  # pipes: " | " between git/PR/model/tokens/time/effort

# Right side: directory path (replace /Users/shlomi with ~)
right_side_text="📁 ${cwd/#\/Users\/shlomi/~}"
right_side=$(printf "${green}%s${reset}" "$right_side_text")
right_length=$((${#right_side_text} + 1))  # emoji takes extra width

term_width=$(get_terminal_width)
effective_width=$((term_width - 1))

padding=$((effective_width - left_length - right_length - 1))
if [[ $padding -lt 2 ]]; then
    padding=2
fi

pad_spaces=$(printf '%*s' "$padding" '')

# Output final statusline
printf "%b%s%b\n" "$output" "$pad_spaces" "$right_side"
