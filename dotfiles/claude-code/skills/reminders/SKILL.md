---
description: List, create, or remove macOS Reminders
argument-hint: [list | add "title" daily/weekly/once | remove "title"]
allowed-tools: Bash
---

# macOS Reminders Manager

The user invoked this command with: $ARGUMENTS

## Instructions

Use `osascript` (AppleScript) to interact with the macOS Reminders app. Parse the user's arguments and perform ONE of the following actions:

### List reminders

If the argument is `list` or empty, list all incomplete reminders across all lists:

```bash
osascript -e '
tell application "Reminders"
    set output to ""
    repeat with reminderList in every list
        set listName to name of reminderList
        repeat with r in (every reminder in reminderList whose completed is false)
            set rName to name of r
            set rDate to ""
            try
                set rDate to remind me date of r as string
            end try
            set rBody to ""
            try
                set rBody to body of r
            end try
            set output to output & "• [" & listName & "] " & rName
            if rDate is not "" then set output to output & " (due: " & rDate & ")"
            if rBody is not "" then set output to output & " — " & rBody
            set output to output & linefeed
        end repeat
    end repeat
    return output
end tell'
```

### Add a reminder

If the argument starts with `add`, create a new reminder. Parse the title, optional body, optional recurrence (daily, weekly, monthly, once), and optional time from the arguments.

For recurring reminders, set the remind me date to today (or tomorrow if time has passed) at the specified time (default 9:00 AM), and set recurrence.

Example AppleScript for a daily reminder:
```bash
osascript -e '
tell application "Reminders"
    tell default list
        set newReminder to make new reminder with properties {name:"TITLE", body:"BODY"}
        set remind me date of newReminder to date "DATE_STRING"
        set recurrence of newReminder to {frequency:daily}
    end tell
end tell'
```

Recurrence frequency values: `daily`, `weekly`, `monthly`, `yearly`. Omit recurrence for one-time reminders.

### Remove a reminder

If the argument starts with `remove` or `delete`, find and delete the reminder by name:

```bash
osascript -e '
tell application "Reminders"
    repeat with reminderList in every list
        try
            delete (first reminder in reminderList whose name is "TITLE" and completed is false)
            return "Deleted: TITLE"
        end try
    end repeat
    return "Not found: TITLE"
end tell'
```

## Important notes

- Always show the user what you're about to do before running the command
- For `add`: if no time is specified, default to 9:00 AM
- For `add`: if no recurrence is specified, default to a one-time reminder for tomorrow
- Format dates for AppleScript as: "Monday, June 9, 2026 at 9:00:00 AM" (use the system locale format)
- After creating or deleting, confirm the action to the user
- If arguments are ambiguous, ask for clarification
