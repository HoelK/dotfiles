export SHELL=/bin/zsh

setopt PROMPT_SUBST
setopt histignorealldups

if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
  exec start-hyprland
fi

autoload -Uz compinit promptinit
compinit
promptinit

##Prompt
git_branch() { echo "$(git symbolic-ref HEAD 2> /dev/null | cut -d'/' -f3)" }
PROMPT='╭─ (%n) (%~) ($(git_branch))
╰─>'

##Aliases
alias ccomp="gcc -Wall -Werror -Wextra -g -Wuninitialized"
alias unpack="tar -xvzf"
alias c3="~/c3/c3c compile"

##Envs
export PATH=$PATH:/home/Keos/.venv/bin
. "$HOME/.local/bin/env"

##Keymaps
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
bindkey '^H' backward-kill-word
