#!/usr/bin/env bash
# Which profile `claude` starts, and what it hands Claude Code.
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/helpers.sh"

section "Nothing remembered: the default profile, with CLAUDE_CONFIG_DIR unset"
claude
check "runs with the variable unset, not set to ~/.claude" "unset|" "$(launched)"

section "A profile named first is started, and remembered"
profile personal
claude personal -r
check "starts personal, with only the rest as arguments" "$P|-r" "$(launched)"
check "remembers it" personal "$(cat "$XDG_STATE_HOME/claude-profiles/last")"
claude -c
check "the next bare claude starts it again" "$P|-c" "$(launched)"
claude default
check "the default can be named too" "unset|" "$(launched)"
claude
check "and is then the one remembered" "unset|" "$(launched)"

section "Anything that isn't a profile goes to Claude Code as it is"
profile personal
claude personal
claude "fix the tests"
check "a prompt runs in the remembered profile" "$P|fix the tests" "$(launched)"
mkdir "$HOME/.claude-junk"
claude junk
check "a ~/.claude-* Claude Code never started in isn't a profile" "$P|junk" "$(launched)"
claude ../etc
check "nor is a path" "$P|../etc" "$(launched)"

section "A renamed default is found by its name"
profile personal
claude-profiles rename default work >/dev/null
claude work --resume abc
check "work is ~/.claude" "unset|--resume abc" "$(launched)"
claude default
check "and 'default' is no longer special" "unset|default" "$(launched)"

section "An explicit CLAUDE_CONFIG_DIR wins over the remembered profile"
profile personal
profile other
claude other
launched >/dev/null
CLAUDE_CONFIG_DIR=$P claude --resume abc
check "a copied resume command means what it says" "$P|--resume abc" "$(launched)"
check "without changing what's remembered" other "$(cat "$XDG_STATE_HOME/claude-profiles/last")"
CLAUDE_CONFIG_DIR=$HOME/.claude claude
check "set to ~/.claude, it is unset instead" "unset|" "$(launched)"
CLAUDE_CONFIG_DIR=$P claude other
check "but naming a profile is more explicit still" "$HOME/.claude-other|" "$(launched)"

section "A remembered profile that no longer exists falls back to the default"
profile gone
claude gone
rm -r "$HOME/.claude-gone"
claude
check "starts the default" "unset|" "$(launched)"

section "Claude Code's exit status comes back out"
CLAUDE_STUB_STATUS=3 claude
check "status" 3 $?

section "Profiles are brought into line before the launch"
profile personal
mkdir -p "$HOME/.claude/skills"
echo '{"theme": "dark"}' >"$HOME/.claude/settings.json"
claude personal
check "shared entries are linked" "link:$HOME/.claude/skills" "$(kind "$P/skills")"
check "settings.json among them" "link:$HOME/.claude/settings.json" "$(kind "$P/settings.json")"
start=$EPOCHREALTIME
claude personal
echo "  (a launch with nothing to do took $(((${EPOCHREALTIME/./} - ${start/./}) / 1000)) ms)"

section "An account's own settings are passed on top of the shared ones"
profile personal
echo '{"model": "sonnet"}' >"$P/account-settings.json"
claude personal -r
check "for a profile" "$P|--settings $P/account-settings.json -r" "$(launched)"
echo '{"model": "opus"}' >"$HOME/.claude/account-settings.json"
claude default
check "and for the default" "unset|--settings $HOME/.claude/account-settings.json" "$(launched)"
rm "$HOME/.claude/account-settings.json"
claude default
check "only when there are any" "unset|" "$(launched)"

section "zsh and fish get the same claude"
profile personal
for shell in zsh fish; do
    if ! command -v $shell >/dev/null; then
        echo "  - $shell isn't installed here; skipped"
        continue
    fi
    if [[ $shell == zsh ]]; then
        zsh -f -c "source '$REPO/shell/claude-profiles.bash'; claude personal -r"
    else
        fish --no-config -c "source '$REPO/shell/claude-profiles.fish'; claude personal -r"
    fi
    check "$shell: claude personal -r" "$P|-r" "$(launched)"
done

finish
