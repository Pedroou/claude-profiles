#!/usr/bin/env bash
# claude-profiles: list, add, remove, rename - and install.sh.
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/helpers.sh"

section "The list: every profile, its account, and the one claude opens"
profile personal me@home.example
profile unused
claude personal
running "$HOME/.claude" 11
running "$HOME/.claude" 12
mapfile -t rows < <(claude-profiles)
check "one row per profile, default first, then where the rest is" 5 "${#rows[@]}"
check "the default, its account, and what's running" 1 \
    "$(grep -cE '^  default +me@work\.example +~/\.claude +2 running$' <<<"${rows[0]}")"
check "the remembered one is marked" 1 \
    "$(grep -cE '^● personal +me@home\.example +~/\.claude-personal *$' <<<"${rows[1]}")"
check "a profile nobody has logged into says so" 1 "$(grep -c 'unused.*not logged in' <<<"${rows[2]}")"
check "and under it, where the rest of the commands are" "Run 'claude-profiles help' to see all commands." "${rows[4]}"
rm -r "$P"
check "with nothing valid remembered, the default is marked" 1 "$(claude-profiles | grep -c '^● default')"

section "add: a new profile, set up like the others, logged into nothing"
mkdir -p "$HOME/.claude/skills"
echo '{"theme": "dark"}' >"$HOME/.claude/settings.json"
jq -n '{oauthAccount: {emailAddress: "me@work.example"}, userID: "u1",
        hasCompletedOnboarding: true, theme: "dark",
        projects: {"/code/app": {hasTrustDialogAccepted: true, lastCost: 3}}}' >"$HOME/.claude.json"
said=$(claude-profiles add personal)
state=$P/.claude.json
check "it exists, and is a profile" "$P" "$(claude-profiles _names | grep '^personal' | cut -f2 | sed "s|^~|$HOME|")"
check "onboarding is already done" true "$(jq .hasCompletedOnboarding "$state")"
check "trusted folders stay trusted" true "$(jq '.projects["/code/app"].hasTrustDialogAccepted' "$state")"
check "but nothing else about a project comes along" null "$(jq '.projects["/code/app"].lastCost' "$state")"
check "and nothing about the account" null "$(jq -c '[.oauthAccount, .userID] | map(select(. != null)) | first' "$state")"
check "the state file is private" 600 "$(stat -c %a "$state")"
check "what's shared is linked" "link:$HOME/.claude/skills" "$(kind "$P/skills")"
check "settings.json included" "link:$HOME/.claude/settings.json" "$(kind "$P/settings.json")"
check "it says how to log in" 1 "$(grep -c 'claude personal, then /login' <<<"$said")"

section "add refuses names that can't work"
profile taken
claude-profiles add Personal 2>/dev/null
check "not lowercase" 1 $?
claude-profiles add ../x 2>/dev/null
check "not a path" 1 $?
claude-profiles add taken 2>/dev/null
check "not one that exists" 1 $?
claude-profiles add default 2>/dev/null
check "not the default's" 1 $?
said=$(claude-profiles add plugins 2>&1)
check "not one of Claude Code's commands, asked of Claude Code" 1 "$(grep -c "one of Claude Code's own commands" <<<"$said")"
claude-profiles add 2>/dev/null
check "and a name is needed" 2 $?

section "remove: the login goes, nothing shared does"
profile personal
mkdir -p "$HOME/.claude/projects/-p"
echo transcript >"$HOME/.claude/projects/-p/s.jsonl"
claude personal
echo n | claude-profiles remove personal >/dev/null
check "answering no keeps it" dir "$(kind "$P")"
echo y | claude-profiles remove personal >/dev/null
check "answering yes removes it" none "$(kind "$P")"
check "and says where the rest went" dir "$(kind "$HOME"/.claude/backups/removed-personal-*)"
check "the shared transcripts are still there" transcript "$(cat "$HOME/.claude/projects/-p/s.jsonl")"
check "claude goes back to the default" default "$(cat "$XDG_STATE_HOME/claude-profiles/last")"

section "remove won't take the default, a profile in use, or one that isn't there"
profile busy
running "$HOME/.claude-busy" 55
echo y | claude-profiles remove busy 2>/dev/null
check "a running profile stays" dir "$(kind "$HOME/.claude-busy")"
echo y | claude-profiles remove default 2>/dev/null
check "the default stays" dir "$(kind "$HOME/.claude")"
said=$(echo y | claude-profiles remove nobody 2>&1)
check "no such profile is an error" 1 $?
check "and says so" "claude-profiles: there's no profile called 'nobody'." "$said"

section "remove keeps everything but the login"
profile personal
mkdir -p "$HOME/.claude/projects"
claude personal
mkdir -p "$P/agents/mine"
echo agent >"$P/agents/mine/a.md"
echo secret >"$P/.credentials.json"
echo y | claude-profiles remove personal >/dev/null 2>&1
check "its own files join the shared copy" agent "$(cat "$HOME/.claude/agents/mine/a.md")"
kept=("$HOME"/.claude/backups/removed-personal-*)
check "what's left is kept aside" file "$(kind "$kept/.claude.json")"
check "except the login" none "$(kind "$kept/.credentials.json")"
check "and the links into the shared copy" none "$(kind "$kept/projects")"
check "while the shared copy itself is untouched" dir "$(kind "$HOME/.claude/projects")"

section "rename"
profile personal
claude personal
claude-profiles rename personal home >/dev/null
check "the directory moves" dir "$(kind "$HOME/.claude-home")"
check "the old one is gone" none "$(kind "$P")"
check "and claude still opens it" home "$(cat "$XDG_STATE_HOME/claude-profiles/last")"
hub=$HOME/.claude/plugins
mkdir -p "$hub"
jq -n --arg p "$HOME/.claude-home/plugins" '{plugins: {"a@mp": [{installPath: "\($p)/cache/a"}]}}' >"$hub/installed_plugins.json"
claude-profiles rename home other >/dev/null
check "plugin paths recorded through the old name are pointed at the shared copy" "$hub/cache/a" \
    "$(jq -r '.plugins["a@mp"][0].installPath' "$hub/installed_plugins.json")"
claude-profiles rename other home >/dev/null
claude-profiles rename default work >/dev/null
check "the default can be renamed" "work	~/.claude" "$(claude-profiles _names | head -1)"
check "which is only a name: ~/.claude stays put" dir "$(kind "$HOME/.claude")"
claude-profiles rename work home 2>/dev/null
check "not to a name that's taken" 1 $?

section "install.sh"
rc=$HOME/.bashrc
echo "# mine" >"$rc"
mkdir -p "$HOME/.local/bin"
echo mine >"$HOME/.local/bin/claude-profiles"
out=$(XDG_CONFIG_HOME=$HOME/.config "$REPO/install.sh")
check "it finishes" 0 $?
check "the command is linked" "link:$REPO/bin/claude-profiles" "$(kind "$HOME/.local/bin/claude-profiles")"
check "a file that was there is moved aside" mine "$(cat "$HOME/.local/bin/claude-profiles.bak")"
check "bash sources the wrapper" 1 "$(grep -cF "$REPO/shell/claude-profiles.bash" "$rc")"
check "and keeps what it had" "# mine" "$(head -1 "$rc")"
if command -v fish >/dev/null; then
    check "fish gets its own" "link:$REPO/shell/claude-profiles.fish" "$(kind "$HOME/.config/fish/conf.d/claude-profiles.fish")"
fi
XDG_CONFIG_HOME=$HOME/.config "$REPO/install.sh" >/dev/null
check "running it again adds nothing" 2 "$(wc -l <"$rc")"
check "and the line works" "$P|-r" "$(profile personal; bash -c "source '$rc'; claude personal -r"; launched)"

finish
