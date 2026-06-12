# Global Instructions

## Git Push to Private `shlomiv` Repos

The global gitconfig has `url.git@github.com:.insteadOf=https://github.com/` which forces SSH for all GitHub repos. The SSH key loaded by default (`shlomi-dr`) doesn't have access to personal `shlomiv` repos.

To push to `shlomiv` private repos, temporarily unset the global insteadOf, push via HTTPS (gh credential helper authenticates as `shlomiv`), then restore:

```bash
git config --global --unset url.git@github.com:.insteadOf && git push 2>&1; PUSH_EXIT=$?; git config --global url.git@github.com:.insteadOf https://github.com/; exit $PUSH_EXIT
```

Prerequisites:
- `gh auth switch --user shlomiv` (if not already active)
- `gh auth setup-git` (one-time, sets gh as credential helper)
- Remote must be HTTPS: `git remote set-url origin https://github.com/shlomiv/<repo>.git`
