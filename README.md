<div align="center">

<h1>Claude Profiles</h1>

<p><b>Multiple Anthropic accounts, one Claude Code.</b></p>

<p>
<img alt="Linux" src="https://img.shields.io/badge/Linux-informational?style=flat-square&logo=linux&logoColor=white&labelColor=2d333b">
<img alt="bash, zsh and fish" src="https://img.shields.io/badge/bash_%7C_zsh_%7C_fish-4eaa25?style=flat-square&logo=gnubash&logoColor=white&labelColor=2d333b">
<a href="https://github.com/Pedroou/claude-profiles/releases/latest"><img alt="latest release" src="https://img.shields.io/github/v/release/Pedroou/claude-profiles?style=flat-square&label=release&labelColor=2d333b"></a>
<a href="https://github.com/Pedroou/claude-profiles/actions/workflows/tests.yml"><img alt="tests" src="https://img.shields.io/github/actions/workflow/status/Pedroou/claude-profiles/tests.yml?branch=main&style=flat-square&label=tests&labelColor=2d333b"></a>
<a href="LICENSE"><img alt="MIT licence" src="https://img.shields.io/badge/licence-MIT-blue?style=flat-square&labelColor=2d333b"></a>
</p>

<p>
<a href="#features">Features</a> •
<a href="#using-it">Using it</a> •
<a href="#what-is-shared">What is shared</a> •
<a href="#install">Install</a> •
<a href="#how-it-works">How it works</a>
</p>

</div>

Claude Code holds one login per config directory, and by default there's only
one, `~/.claude`. `CLAUDE_CONFIG_DIR` gives you a second one, along with a
second copy of everything else: CLAUDE.md, skills, plugins, settings, and every
past session. So `/resume` in one account can't see what you did in the other.

**Claude Profiles** keeps the logins apart and everything else as one.

## Features

- **One Claude Code** - CLAUDE.md, skills, plugins, settings and every session
  are a single copy that every profile uses.
- **Per-profile where it matters** - the login, and any setting you pin to one
  profile, like its model.
- **Nothing to sync** - no prompts, no copying, nothing to remember to run.
- **Any number of profiles**, in bash, zsh or fish.

## Using it

Commands:

```sh
claude [<args>…]                     # Claude Code, in the profile you used last
claude <profile> [<args>…]           # in that profile, which is then the one used last
claude-profiles                      # list profiles, their accounts, and what's running
claude-profiles add <name>           # add a profile; then `claude <name>` and /login
claude-profiles remove <name>        # remove one; only its login goes
claude-profiles rename <old> <new>   # rename one, the default included
claude-profiles help                 # every command
```

`claude-profiles` output on a machine with 2 profiles (each linked to a
different Anthropic account):

```
● work       you@company.com   ~/.claude            2 running
  personal   you@example.com   ~/.claude-personal

Run 'claude-profiles help' to see all commands.
```

The profile marked with `●` is the one plain `claude` opens. Your existing
`~/.claude` becomes the first profile, called `default` until you rename it.

## What is shared

| One copy, in `~/.claude` | Each profile's own |
|---|---|
| `CLAUDE.md`, rules, skills, agents, commands, output styles, keybindings | The login |
| `settings.json` and plugins | `account-settings.json` |
| All sessions (`/resume` and `/rewind` work across all profiles) | Claude Code's state file, caches, the live session list |
| Prompt history, todos, plans | Org-managed settings |

Each shared entry is a symlink from the profile to `~/.claude`.

`account-settings.json` sits in each profile's directory (the default's is
`~/.claude/account-settings.json`). Its settings apply to that profile alone
and win over the shared ones. One example is the model, since account plans
differ in what models they can run:

```json
{ "model": "sonnet" }
```

`/model` and `/effort` change the shared default. A profile with its own model
keeps it. Login settings such as `apiKeyHelper` or API keys belong in
`account-settings.json` too, or every profile would use them.

Every profile sees every session. So for instance, if your work transcripts
mustn't be readable from your personal account, keep that profile under another
machine user.

## Install

Requires **Linux**, `bash` 4.4+, `jq` and GNU coreutils. `rsync` is only needed
to merge a profile that already had sessions of its own.

```sh
git clone https://github.com/Pedroou/claude-profiles
cd claude-profiles
./install.sh        # links into ~/.local/bin and your shells, so 'git pull' updates it
```

`install.sh` checks every requirement first, then gives `claude` to bash, and
to zsh and fish if you have them.

## How it works

**Launching.** `claude` is a one-line shell function for `claude-profiles
launch`, a bash script. It links whatever each profile is missing to the shared
copy, then starts Claude Code with that profile's `CLAUDE_CONFIG_DIR`, plus
`--settings account-settings.json` when the profile has one. This takes under
15 ms.

**Joining.** A profile that already had its own copy of something joins the
shared copy once, when nothing is running in it. Its sessions are merged in.
Anything else it had is set aside in `~/.claude/backups/`, and one line says
what moved.

[`docs/design.md`](docs/design.md) has the reasoning for the design decisions.
The tests run the real script against a throwaway `$HOME`, a stand-in `claude`
and a fake `/proc`:

```sh
test/run.sh
```

## Limitations

- **Anything that runs `claude` outside your shell** (an IDE extension, a
  script) gets the default profile. A script can run
  `claude-profiles launch <profile> …` instead.
- **User-scope MCP servers** live in Claude Code's state file, next to the
  login, so they stay per profile. A new profile starts with a copy of the
  default's.
- **Linux only.** Running sessions are found through `/proc`.
- A prompt sent through the CLI that is exactly a profile's name
  (`claude personal`) opens that profile.

## Works with

**[Agent Session Manager](https://github.com/Pedroou/agent-session-manager)**,
a Plasma panel widget that shows your Claude Code sessions' status, per
profile. Neither one depends on the other.

**[OMP](https://github.com/can1357/oh-my-pi)** keeps its own logins, and
reads the shared `~/.claude` like any profile.

## Licence

MIT - see [LICENSE](LICENSE).

<sub>Unofficial, and not affiliated with or endorsed by Anthropic. Claude and
Claude Code are trademarks of Anthropic, PBC.</sub>
