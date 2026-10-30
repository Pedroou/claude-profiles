# claude-profiles for bash and zsh, sourced from ~/.bashrc or ~/.zshrc by install.sh.
claude() { claude-profiles launch "$@"; }

# The rest is bash's completion, which zsh never reads past this line.
[ -n "${BASH_VERSION-}" ] || return 0

_claude_profiles_names() {
    local name
    while IFS=$'\t' read -r name _; do printf '%s\n' "$name"; done < <(claude-profiles _names)
}
_claude_profiles() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    if ((COMP_CWORD == 1)); then
        mapfile -t COMPREPLY < <(compgen -W "list add remove rename help" -- "$cur")
    elif ((COMP_CWORD == 2)) && [[ ${COMP_WORDS[1]} == @(remove|rm|rename|mv) ]]; then
        mapfile -t COMPREPLY < <(compgen -W "$(_claude_profiles_names)" -- "$cur")
    fi
}
_claude_profiles_claude() {
    ((COMP_CWORD == 1)) || return
    mapfile -t COMPREPLY < <(compgen -W "$(_claude_profiles_names)" -- "${COMP_WORDS[1]}")
}
complete -F _claude_profiles claude-profiles
# Profile names as claude's first argument, unless claude has completions of its own.
complete -p claude >/dev/null 2>&1 || complete -o default -F _claude_profiles_claude claude
