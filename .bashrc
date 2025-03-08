#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

export PATH="/home/marques/.local/bin:$PATH"

eval "$(starship init bash)"

# aliases
if [ -e ~/.bashrc.aliases ] ; then
   source ~/.bashrc.aliases
fi

neofetch
