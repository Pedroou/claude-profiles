#!/usr/bin/env bash
# What profiles share, and how a profile's own copy joins the shared one.
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/helpers.sh"

section "A new profile links to everything shared that exists"
profile personal
mkdir -p "$HOME/.claude/projects" "$HOME/.claude/skills" "$HOME/.claude/plugins"
echo "# mine" >"$HOME/.claude/CLAUDE.md"
touch "$HOME/.claude/history.jsonl" "$HOME/.claude/settings.json"
said=$(share)
for entry in projects skills plugins CLAUDE.md history.jsonl settings.json; do
    check "$entry is shared" "link:$HOME/.claude/$entry" "$(kind "$P/$entry")"
done
check "what doesn't exist isn't linked" none "$(kind "$P/agents")"
check "the account's own files aren't touched" file "$(kind "$P/.claude.json")"
check "and nothing is said" "" "$said"
check "a second run changes nothing" "" "$(share)"

section "A profile's own copy moves over when there is no shared one"
profile personal
mkdir -p "$P/agents"
echo reviewer >"$P/agents/reviewer.md"
share >/dev/null
check "it becomes the shared copy" reviewer "$(cat "$HOME/.claude/agents/reviewer.md")"
check "and is linked back" "link:$HOME/.claude/agents" "$(kind "$P/agents")"

section "...even while a session is running there"
profile personal
running "$P" 101
mkdir -p "$P/commands"
share >/dev/null
check "a move is safe mid-session" "link:$HOME/.claude/commands" "$(kind "$P/commands")"

section "Two copies of a session directory are merged, and every losing version is kept"
profile personal
s=$HOME/.claude/projects/-p
mkdir -p "$s" "$P/projects/-p"
echo shared-only >"$s/a.jsonl"
echo personal-only >"$P/projects/-p/b.jsonl"
echo old-shared >"$s/c.jsonl"
echo new-personal >"$P/projects/-p/c.jsonl"
touch -d '1 day ago' "$s/c.jsonl"
echo new-shared >"$s/d.jsonl"
echo old-personal >"$P/projects/-p/d.jsonl"
touch -d '1 day ago' "$P/projects/-p/d.jsonl"
echo same >"$s/e.jsonl"
cp -p "$s/e.jsonl" "$P/projects/-p/e.jsonl"
said=$(share)
check "shared-only file kept" shared-only "$(cat "$s/a.jsonl")"
check "personal-only file brought over" personal-only "$(cat "$s/b.jsonl")"
check "personal's newer version wins" new-personal "$(cat "$s/c.jsonl")"
check "the shared newer version wins" new-shared "$(cat "$s/d.jsonl")"
check "now linked" "link:$HOME/.claude/projects" "$(kind "$P/projects")"
backup=("$HOME"/.claude/backups/profiles-*-personal/projects/-p)
check "the shared version that lost is backed up" old-shared "$(cat "$backup/c.jsonl")"
check "so is personal's" old-personal "$(cat "$backup/d.jsonl")"
check "identical files aren't" none "$(kind "$backup/e.jsonl")"
check "it says what it merged" "claude-profiles: merged personal's own projects into the shared copy." "${said%%$'\n'*}"

section "...but not while a session is running in the profile"
profile personal
mkdir -p "$HOME/.claude/projects" "$P/projects" "$HOME/.claude/skills"
running "$P" 202
said=$(share)
check "the merge waits" dir "$(kind "$P/projects")"
check "while plain links still happen" "link:$HOME/.claude/skills" "$(kind "$P/skills")"
check "and it says it's waiting" 1 "$(grep -c 'next time nothing is running' <<<"$said")"
rm "$P/sessions/202.json"
share >/dev/null
check "once it's idle, it goes ahead" "link:$HOME/.claude/projects" "$(kind "$P/projects")"

section "A record left by a killed session doesn't count as running"
profile personal
running "$P" 303
echo "303 (claude) S 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 9999" >"$CLAUDE_PROFILES_PROC/303/stat"
mkdir -p "$HOME/.claude/todos" "$P/todos"
share >/dev/null
check "a recycled pid is not the session" "link:$HOME/.claude/todos" "$(kind "$P/todos")"
running "$P" 304
rm -r "$CLAUDE_PROFILES_PROC/304"
check "nor is a pid that's gone" 0 "$(claude-profiles | grep -c running)"

section "Without rsync, a merge waits rather than half-happening"
profile personal
mkdir -p "$HOME/.claude/projects" "$P/projects"
echo mine >"$P/projects/a.jsonl"
said=$(PATH=$ROOT/bin:$REPO/bin:/nonexistent "$(command -v bash)" "$REPO/bin/claude-profiles" launch 2>&1 >/dev/null)
check "the profile keeps its own" mine "$(cat "$P/projects/a.jsonl")"
check "and says rsync is what's missing" 1 "$(grep -c 'needs rsync' <<<"$said")"

section "Anything else both sides have is set aside, not guessed at"
profile personal
echo "shared rules" >"$HOME/.claude/CLAUDE.md"
echo "personal rules" >"$P/CLAUDE.md"
echo '{"display":"one"}' >"$HOME/.claude/history.jsonl"
echo '{"display":"two"}' >"$P/history.jsonl"
mkdir -p "$HOME/.claude/skills/a" "$P/skills/b"
said=$(share)
backup=("$HOME"/.claude/backups/profiles-*-personal)
check "the shared CLAUDE.md stands" "shared rules" "$(cat "$HOME/.claude/CLAUDE.md")"
check "personal's is in the backup" "personal rules" "$(cat "$backup/CLAUDE.md")"
check "so is its history" '{"display":"two"}' "$(cat "$backup/history.jsonl")"
check "and its skills" dir "$(kind "$backup/skills/b")"
check "all three are linked now" "link:$HOME/.claude/CLAUDE.md link:$HOME/.claude/history.jsonl link:$HOME/.claude/skills" \
    "$(kind "$P/CLAUDE.md") $(kind "$P/history.jsonl") $(kind "$P/skills")"
check "it says what it set aside, and where" 2 "$(grep -cE 'had its own|backups/profiles-' <<<"$said")"

section "Joining settings.json keeps the model settings each account had as its own"
profile personal
echo '{"model": "opus[1m]", "effortLevel": "xhigh", "theme": "dark"}' >"$HOME/.claude/settings.json"
echo '{"model": "sonnet", "effortLevel": "xhigh", "theme": "light"}' >"$P/settings.json"
said=$(share)
check "settings.json is shared" "link:$HOME/.claude/settings.json" "$(kind "$P/settings.json")"
check "the shared settings stand" '"dark"' "$(jq .theme "$HOME/.claude/settings.json")"
check "personal keeps the model it had, and only what differed" '{"model":"sonnet"}' "$(jq -c . "$P/account-settings.json")"
check "so does the default" '{"model":"opus[1m]"}' "$(jq -c . "$HOME/.claude/account-settings.json")"
check "personal's whole file is in the backup" '"light"' "$(jq .theme "$HOME"/.claude/backups/profiles-*-personal/settings.json)"
check "it says what each account kept" 2 "$(grep -c "keeps that account's own" <<<"$said")"

section "...without overwriting settings an account already keeps"
profile personal
echo '{"model": "opus"}' >"$HOME/.claude/settings.json"
echo '{"model": "sonnet"}' >"$P/settings.json"
echo '{"model": "haiku"}' >"$HOME/.claude/account-settings.json"
share >/dev/null
check "the default's stay" '{"model":"haiku"}' "$(jq -c . "$HOME/.claude/account-settings.json")"
check "personal's are written" '{"model":"sonnet"}' "$(jq -c . "$P/account-settings.json")"

section "A link you made yourself is left alone"
profile personal
mkdir -p "$ROOT/elsewhere" "$HOME/.claude/skills"
ln -s "$ROOT/elsewhere" "$P/skills"
share >/dev/null
check "still points where you pointed it" "link:$ROOT/elsewhere" "$(kind "$P/skills")"

section "A profile's own plugins are set aside, and the shared ones used"
profile personal
mkdir -p "$HOME/.claude/plugins/cache/mp/a/2.0" "$P/plugins/cache/mp/a/1.0"
share >/dev/null
check "plugins are shared" "link:$HOME/.claude/plugins" "$(kind "$P/plugins")"
check "the profile's own copy is in the backup" dir "$(kind "$HOME"/.claude/backups/profiles-*-personal/plugins/cache/mp/a/1.0)"

section "Plugin paths recorded through a profile are pointed at the shared copy"
profile personal
hub=$HOME/.claude/plugins
mkdir -p "$hub"
ln -s "$hub" "$P/plugins"
jq -n --arg p "$P/plugins" --arg h "$hub" '{version: 2, plugins: {
        "a@mp": [{installPath: "\($p)/cache/mp/a/1.0"}],
        "b@mp": [{installPath: "\($h)/cache/mp/b/1.0"}]}}' >"$hub/installed_plugins.json"
jq -n --arg p "$P/plugins" '{mp: {installLocation: "\($p)/marketplaces/mp"}}' >"$hub/known_marketplaces.json"
share >/dev/null
check "an installed plugin's path" "$hub/cache/mp/a/1.0" "$(jq -r '.plugins["a@mp"][0].installPath' "$hub/installed_plugins.json")"
check "one already right is left as it is" "$hub/cache/mp/b/1.0" "$(jq -r '.plugins["b@mp"][0].installPath' "$hub/installed_plugins.json")"
check "a marketplace's path" "$hub/marketplaces/mp" "$(jq -r .mp.installLocation "$hub/known_marketplaces.json")"
check "the registry keeps its version" 2 "$(jq .version "$hub/installed_plugins.json")"
before=$(stat -c %Y.%i "$hub/installed_plugins.json")
share >/dev/null
check "and once right, the file isn't rewritten" "$before" "$(stat -c %Y.%i "$hub/installed_plugins.json")"

finish
