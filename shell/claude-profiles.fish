# claude-profiles for fish, linked into ~/.config/fish/conf.d by install.sh.
function claude --description 'Claude Code, in the profile you name or the one you used last'
    claude-profiles launch $argv
end

# Profile names as claude's first argument, added to whatever completions it has.
complete -c claude -n __fish_is_first_arg -a '(claude-profiles _names)'

complete -c claude-profiles -f
complete -c claude-profiles -n __fish_use_subcommand -a list -d 'List your profiles'
complete -c claude-profiles -n __fish_use_subcommand -a add -d 'Add a profile, for another account'
complete -c claude-profiles -n __fish_use_subcommand -a remove -d 'Remove a profile; what is shared stays'
complete -c claude-profiles -n __fish_use_subcommand -a rename -d 'Rename a profile'
complete -c claude-profiles -n __fish_use_subcommand -a help -d 'Show every command'
complete -c claude-profiles -n '__fish_seen_subcommand_from remove rm rename mv; and __fish_is_nth_token 2' \
    -a '(claude-profiles _names)'
