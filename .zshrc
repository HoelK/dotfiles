export SHELL=/bin/zsh

setopt PROMPT_SUBST
setopt histignorealldups

autoload -Uz compinit promptinit
compinit
promptinit

##Prompt
git_branch() { echo "$(git symbolic-ref HEAD 2> /dev/null | cut -d'/' -f3)" }
PROMPT='╭─ (%n) (%~) ($(git_branch))#
╰─>'

##Aliases
alias ccomp=gcc -Wall -Werror -Wextra -g -Wuninitialized
alias memdebug=valgrind --leak-check=full --track-origins=yes

#export PATH=$PATH:/home/Keos/.venv/bin
#export PATH=$PATH:/home/Keos/.venv/bin
#export PATH=$PATH:/home/Keos/.venv/bin
