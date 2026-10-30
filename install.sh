#!/usr/bin/env bash
# Install (or update) claude-profiles for the current user.
#
# Links the command into ~/.local/bin and gives each shell you have its `claude`
# function. Everything is linked to this checkout, so `git pull` is an update.
# Safe to re-run.

here=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
bin=$HOME/.local/bin

if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4))); then
    echo "✗ claude-profiles needs bash 4.4 or newer; this is $BASH_VERSION."
    exit 1
fi
for tool in jq realpath find; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "✗ $tool is required but not on \$PATH."
        exit 1
    fi
done
# mv -T and ln -T are what keep two launches at once from nesting a directory.
if ! mv --help 2>&1 | grep -q -- '--no-target-directory'; then
    echo "✗ claude-profiles needs GNU coreutils (mv -T, ln -T)."
    exit 1
fi
command -v rsync >/dev/null 2>&1 ||
    echo "! rsync isn't installed. It's only needed to merge a profile that already has its own sessions."
command -v claude >/dev/null 2>&1 ||
    echo "! Claude Code isn't on \$PATH yet. Install it, then use \`claude\` as usual."

# A file of yours where a link goes is moved aside, never overwritten.
link() {
    local target=$2 aside
    mkdir -p "$(dirname "$target")"
    if [[ -e $target && ! -L $target ]]; then
        aside=$target.bak
        [[ -e $aside ]] && aside=$target.$(date +%Y%m%d-%H%M%S).bak
        mv "$target" "$aside"
        echo "→ Moved your own $target aside, to $aside"
    fi
    ln -sfn "$1" "$target"
}

link "$here/bin/claude-profiles" "$bin/claude-profiles"
echo "→ Linked claude-profiles into $bin"
[[ :$PATH: == *":$bin:"* ]] || echo "! $bin isn't on \$PATH. Add it, or the shells won't find claude-profiles."

# One line in each rc file, marked so a re-run replaces it rather than adding another.
rc_line() {
    local shell=$1 rc=$2 src
    src=$(printf %q "$here/shell/claude-profiles.bash")
    { [[ -f $rc ]] && grep -v '# claude-profiles$' "$rc"; echo "[ -f $src ] && . $src # claude-profiles"; } \
        >"$rc.claude-profiles.tmp" && cat "$rc.claude-profiles.tmp" >"$rc"
    rm -f "$rc.claude-profiles.tmp"
    echo "→ claude for $shell, in $rc"
}
rc_line bash "$HOME/.bashrc"
command -v zsh >/dev/null 2>&1 && rc_line zsh "${ZDOTDIR:-$HOME}/.zshrc"
if command -v fish >/dev/null 2>&1; then
    conf=${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/claude-profiles.fish
    link "$here/shell/claude-profiles.fish" "$conf"
    echo "→ claude for fish, in $conf"
fi

echo
echo "✓ Installed. Open a new shell, then 'claude-profiles help' lists every command."
