# Shared by every suite. Each one runs the real command against a throwaway
# $HOME, a throwaway /proc and a stand-in `claude`, then checks that the real
# profiles were never touched.

REPO=$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")
PASS=0
FAIL=0
shopt -s nullglob

# Tripwire. The real profiles change on their own - every live session writes
# to them - so this fingerprints what a suite could plausibly break: which
# entries exist and what kind they are, the settings files, and the state
# directory. Taken before anything moves $HOME.
fingerprint() {
    {
        find "$1/.claude" "$1"/.claude-* -mindepth 1 -maxdepth 1 -printf '%y %p\n' 2>/dev/null | sort
        cat "$1/.claude/settings.json" "$1"/.claude-*/settings.json 2>/dev/null
        find "$1/.local/state/claude-profiles" -printf '%y %p %s\n' 2>/dev/null | sort
    } | md5sum
}
REAL_HOME=$HOME
REAL_FP=$(fingerprint "$REAL_HOME")
REAL_PATH=$PATH

check() {
    if [[ $2 == "$3" ]]; then
        PASS=$((PASS + 1))
        echo "  ✓ $1"
    else
        FAIL=$((FAIL + 1))
        echo "  ✗ $1"
        echo "      expected: [$2]"
        echo "      actual:   [$3]"
    fi
}

section() {
    echo
    echo "═══ $1 ═══"
    setup
}

# A fresh machine with a default profile and nothing else. The stand-in claude
# records the profile it was started in and its arguments, and answers --help
# with a slice of the real command list.
setup() {
    ROOT=$(mktemp -d)
    export HOME=$ROOT/home XDG_STATE_HOME=$ROOT/home/.local/state CLAUDE_PROFILES_PROC=$ROOT/proc
    export PATH=$ROOT/bin:$REPO/bin:$REAL_PATH
    unset CLAUDE_CONFIG_DIR CLAUDE_STUB_STATUS
    P=$HOME/.claude-personal
    mkdir -p "$HOME/.claude" "$ROOT/proc" "$ROOT/bin"
    echo '{"oauthAccount": {"emailAddress": "me@work.example"}}' >"$HOME/.claude.json"
    cat >"$ROOT/bin/claude" <<'EOF'
#!/bin/sh
if [ "$1" = --help ]; then
  printf 'Commands:\n  mcp                 Configure MCP servers\n  plugin|plugins      Manage plugins\n  doctor              Check the health\n'
  exit 0
fi
echo "${CLAUDE_CONFIG_DIR-unset}|$*" >"$HOME/launched"
exit "${CLAUDE_STUB_STATUS:-0}"
EOF
    chmod +x "$ROOT/bin/claude"
}

# A second profile Claude Code has already started in.
profile() {
    mkdir -p "$HOME/.claude-$1"
    jq -n --arg e "${2-}" 'if $e == "" then {} else {oauthAccount: {emailAddress: $e}} end' >"$HOME/.claude-$1/.claude.json"
}

# Pretend a session is running in a profile: a record, and a process to match it.
running() {
    mkdir -p "$1/sessions" "$CLAUDE_PROFILES_PROC/$2"
    echo "{\"pid\": $2, \"procStart\": \"4242\"}" >"$1/sessions/$2.json"
    echo "$2 (claude) S 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 4242" >"$CLAUDE_PROFILES_PROC/$2/stat"
}

# What the last launch started, once.
launched() {
    cat "$HOME/launched" 2>/dev/null
    rm -f "$HOME/launched"
}

# Bring every profile into line, the way a launch does, and say what it said.
share() { claude-profiles launch 2>&1 >/dev/null; rm -f "$HOME/launched"; }

kind() {
    if [[ -L $1 ]]; then
        echo "link:$(readlink "$1")"
    elif [[ -d $1 ]]; then
        echo dir
    elif [[ -f $1 ]]; then
        echo file
    else
        echo none
    fi
}

finish() {
    echo
    echo "═══ Tripwire: the real profiles are untouched ═══"
    check "real ~/.claude, ~/.claude-* and state unchanged" "$REAL_FP" "$(fingerprint "$REAL_HOME")"
    echo
    echo "$PASS passed, $FAIL failed"
    ((FAIL == 0))
}

# The `claude` the suites call is the one bash and zsh get.
source "$REPO/shell/claude-profiles.bash"
