# Design

## Goal

Use more than one Claude Code account on one machine, typically a work seat and
a personal subscription, without logging in and out, and without that turning
into more than one Claude Code. The only choice left is which account to start
in, and even that has a default: the one used last.

Non-goals: switching the account of a running session, syncing between
machines (that's a dotfiles job), and launches that bypass the shell function.

## A profile is a directory

Claude Code already has the mechanism: `CLAUDE_CONFIG_DIR` picks the directory
it keeps everything in, the login included. `~/.claude` is the default profile,
and any `~/.claude-<name>` that Claude Code has started in (it holds
`.claude.json` or `.credentials.json`) is another. There is no list of profiles
to keep in step with the disk. The one thing a path can't hold is the default's
name, which is kept in `$XDG_STATE_HOME/claude-profiles/`, next to the last
profile used.

The default runs with `CLAUDE_CONFIG_DIR` unset, never set to `~/.claude`.
When the variable is set, Claude Code looks for its state file inside the
directory, while the default's lives beside it at `~/.claude.json`, so it would
start as if for the first time.

A profile's name is the first argument of `claude`, so `add` refuses Claude
Code's own commands, which it gets from `claude --help` so that new ones are
covered too. A `CLAUDE_CONFIG_DIR` already in the environment wins over the
remembered profile, so a copied `CLAUDE_CONFIG_DIR=… claude --resume <id>`
means what it says.

## Share, don't sync

Two full profiles drift, and syncing them means choosing a direction no one
can choose safely: which side is newer, and what happens to the other? Almost
nothing in a profile is actually about the account, so everything that isn't
becomes one copy, and one copy can't drift.

The shared entries are listed explicitly, so anything a future Claude Code
adds to the directory stays per profile until someone decides otherwise.
`paste-cache/` and `image-cache/` go with `history.jsonl`, because history
entries point into them by hash. `sessions/` stays per profile: it is the live
registry, and it is what attributes a running session to its account. A link,
once made, is never touched again, including one you pointed somewhere
yourself.

`settings.json` is shared like the rest. Claude Code writes through a symlinked
`settings.json`, keeping the link. What has to differ per account goes in
`account-settings.json`, passed with `--settings`, which Claude Code ranks above
user settings. `/model` and `/effort` save to the shared file, so they change
the default for every account without its own model. This replaced a three-way
merge of per-profile settings files: about 450 lines of code and tests, kept
only so that `/model` would also save per account.

### Joining the shared copy

A profile with its own copy where a link belongs (one made before it was
shared, or one where something replaced the link) joins once:

- **The shared side has none:** the copy moves there. A move within a
  filesystem leaves open files open, so this is safe mid-session.
- **Both have one:** this waits until nothing is running in the profile,
  because it pulls files out from under open sessions. Session directories are
  merged with two `rsync --update --backup` passes. The first brings over
  whatever is newer in the profile, backing up the shared version it replaces.
  The second backs up the profile's version wherever the shared one was newer.
  Between them, every losing version is in the backup, and nothing else. This
  is the only use of `rsync`, so without it a profile keeps its own sessions
  until it's installed. Any
  other entry is set aside in `~/.claude/backups/`: two CLAUDE.mds can't be
  merged by a rule, and a plugin cache is fetched again on demand. Before two
  `settings.json` files become one, the `model`, `effortLevel` and
  `advisorModel` they disagree on are written to each side's
  `account-settings.json`, so neither account's model changes.

Plugin registries store absolute paths, and a plugin installed from a profile
is recorded through that profile's link, which breaks once the profile is
renamed or removed. Each launch points such paths back at
`~/.claude/plugins/`. Checking costs a string match, and `jq` only runs when
there's something to fix.

## Is anything running?

The same check Claude Code makes on its own session records: the record's
process must exist, and its start time (field 22 of `/proc/<pid>/stat`) must
match the record's `procStart`. That rules out a record left by a killed
session whose pid has since been reused.

## One script, every shell

Everything is one bash script, `claude-profiles`. Each shell gets a one-line
`claude` function that calls `claude-profiles launch`, so bash, zsh and fish
run the same code, and the script `exec`s Claude Code, which keeps the
terminal and the exit status its own. A launch with nothing to do forks
nothing but the script itself.

## Tests

`test/run.sh` runs the real script against a throwaway `$HOME`, a stand-in
`claude` that records how it was started, and a fake `/proc`, and checks the
zsh and fish functions where those shells are installed (CI installs both).
Before anything moves `$HOME`, each suite fingerprints the real profiles
(which entries exist, of what kind, the settings files and the state
directory) and fails if any of that changed.

## Releases

A release is an annotated tag whose message is the release notes. Pushing it
runs the tests, then publishes the GitHub release.
